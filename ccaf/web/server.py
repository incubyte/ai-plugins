#!/usr/bin/env python3
"""
CCAF Exam Web Server — stdlib only, no external dependencies.

Two modes (select with first positional arg):

  export   --exam-id ID --exam-src PATH --exam-dir DIR
           Parse ~/.claude/ccaf-exam.local.md + .answers.md, write
           DIR/ID.json with Base64-obfuscated answer keys. Then exit.

  serve    --port PORT --exam-dir DIR --plugin-root PATH
           Serve the HTML app and exam API on PORT until a /submit
           POST is received, then shut down cleanly.

Routes (serve mode):
  GET  /             → web/app.html
  GET  /ping         → 200 "pong"  (reuse detection)
  GET  /exams        → JSON list of exams in exam-dir (metadata only)
  GET  /exam/<id>    → full exam JSON (questions + obfuscated keys)
  GET  /result/<id>  → result JSON for a completed exam
  POST /submit       → save result JSON, schedule shutdown
"""

import argparse
import base64
import glob
import json
import os
import re
import sys
import threading
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer


# ---------------------------------------------------------------------------
# Exam file parser
# ---------------------------------------------------------------------------

def parse_questions_file(path):
    """
    Returns (total, scenarios_list, cases_dict, questions_list).

    cases_dict: {slug: {title, brief}}
    questions_list: [{n, domain, scenario, stem, options:{A,B,C,D}}]
    """
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    # -- Strip frontmatter --
    total = 60
    scenarios_str = ""
    i = 0
    if lines and lines[0] == "---":
        i = 1
        while i < len(lines) and lines[i] != "---":
            if lines[i].startswith("total: "):
                total = int(lines[i][7:].strip())
            elif lines[i].startswith("scenarios: "):
                scenarios_str = lines[i][11:].strip()
            i += 1
        i += 1  # skip closing ---

    cases = {}           # slug → {title, brief}
    questions = []
    current_case = None  # slug of the current [[CASE:]] block
    in_case_header = False
    current_q = None     # dict being built

    for line in lines[i:]:
        # Case block header. Slug grammar [a-z0-9-]+ — keep in sync with the
        # awk validator in scripts/ccaf-exam.sh (check_composition_questions).
        m = re.match(r"^\[\[CASE:([a-z0-9-]+)\]\]$", line)
        if m:
            if current_q is not None:
                questions.append(current_q)
                current_q = None
            current_case = m.group(1)
            cases[current_case] = {"title": "", "brief": ""}
            in_case_header = True
            continue

        # Question block header
        m = re.match(r"^\[\[Q(\d+)\]\]$", line)
        if m:
            if current_q is not None:
                questions.append(current_q)
            current_q = {
                "n": int(m.group(1)),
                "domain": "",
                "scenario": current_case or "",
                "stem": "",
                "options": {},
            }
            in_case_header = False
            continue

        # Case-block header fields (title/brief before first Q)
        if in_case_header and current_case:
            if line.startswith("title: "):
                cases[current_case]["title"] = line[7:]
            elif line.startswith("brief: "):
                cases[current_case]["brief"] = line[7:]
            continue

        # Question fields
        if current_q is not None:
            if line.startswith("domain: "):
                current_q["domain"] = line[8:]
            elif line.startswith("stem: "):
                current_q["stem"] = line[6:]
            elif len(line) >= 3 and line[0] in "ABCD" and line[1:3] == ") ":
                current_q["options"][line[0]] = line[3:]

    if current_q is not None:
        questions.append(current_q)

    scenarios_list = [s for s in scenarios_str.split(",") if s]
    return total, scenarios_list, cases, questions


def parse_answers_file(path):
    """Returns {qnum(int): key_letter(str)} from the answers file."""
    keys = {}
    fm_dashes = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line == "---":
                fm_dashes += 1
                continue
            if fm_dashes < 2:
                continue
            # Data line: "N DOMAIN KEY USER"
            parts = line.split()
            if len(parts) == 4 and parts[0].isdigit() and re.match(r"^[A-D]$", parts[2]):
                keys[int(parts[0])] = parts[2]
    return keys


# ---------------------------------------------------------------------------
# Export mode
# ---------------------------------------------------------------------------

IDLE_TIMEOUT = 60  # seconds of browser silence before auto-shutdown

# NOTE: keep in sync with DOMAIN_NAMES in web/app.html
DOMAIN_NAMES = {
    "D1": "Agentic Architecture & Orchestration",
    "D2": "Tool Design & MCP Integration",
    "D3": "Claude Code Configuration & Workflows",
    "D4": "Prompt Engineering & Structured Output",
    "D5": "Context Management & Reliability",
}


def cmd_export(args):
    q_path = args.exam_src + ".md"
    a_path = args.exam_src + ".answers.md"

    if not os.path.exists(q_path):
        sys.exit(f"export: questions file not found: {q_path}")
    if not os.path.exists(a_path):
        sys.exit(f"export: answers file not found: {a_path}")

    total, scenarios_list, cases, questions = parse_questions_file(q_path)
    keys = parse_answers_file(a_path)

    # Domain distribution
    domain_dist = {}
    for q in questions:
        domain_dist[q["domain"]] = domain_dist.get(q["domain"], 0) + 1

    # Build sections in scenario order
    sections = []
    for slug in scenarios_list:
        case = cases.get(slug, {"title": slug, "brief": ""})
        section_qs = []
        for q in questions:
            if q["scenario"] != slug:
                continue
            key_letter = keys.get(q["n"])
            if not key_letter:
                sys.exit(
                    f"export: no answer key for question {q['n']} — check the answers file"
                )
            obfuscated = base64.b64encode(key_letter.encode()).decode()
            section_qs.append({
                "n": q["n"],
                "domain": q["domain"],
                "domain_name": DOMAIN_NAMES.get(q["domain"], q["domain"]),
                "stem": q["stem"],
                "options": q["options"],
                "key": obfuscated,
            })
        sections.append({
            "scenario": slug,
            "title": case["title"],
            "brief": case["brief"],
            "questions": section_qs,
        })

    exam_data = {
        "id": args.exam_id,
        "name": args.name or args.exam_id,
        "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S"),
        "scenarios": scenarios_list,
        "domain_distribution": domain_dist,
        "domain_names": DOMAIN_NAMES,
        "total": total,
        "sections": sections,
    }

    os.makedirs(args.exam_dir, exist_ok=True)
    out_path = os.path.join(args.exam_dir, f"{args.exam_id}.json")
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(exam_data, fh, indent=2, ensure_ascii=False)

    print(f"Exported: {out_path}")


# ---------------------------------------------------------------------------
# HTTP server
# ---------------------------------------------------------------------------

class ExamHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # silence access log
        pass

    def _json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cancel_idle_timer(self):
        timer = getattr(self.server, '_idle_timer', None)
        if timer:
            timer.cancel()
            self.server._idle_timer = None

    def _reset_idle_timer(self):
        self._cancel_idle_timer()
        self.server._idle_timer = threading.Timer(
            IDLE_TIMEOUT,
            lambda: threading.Thread(target=self.server.shutdown, daemon=True).start(),
        )
        self.server._idle_timer.start()

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/") or "/"

        if path == "/ping":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"pong")

        elif path == "/":
            app_path = os.path.join(self.server.plugin_root, "web", "app.html")
            try:
                with open(app_path, "rb") as fh:
                    content = fh.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
            except FileNotFoundError:
                self._json({"error": "app.html not found"}, 404)

        elif path == "/exams":
            self._list_exams()

        elif path.startswith("/exam/"):
            self._serve_exam(path[6:])

        elif path.startswith("/result/"):
            self._serve_result(path[8:])

        elif path == "/heartbeat":
            self._reset_idle_timer()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok")

        elif path == "/reveal":
            self._reveal_folder()

        else:
            self._json({"error": "not found"}, 404)

    def do_DELETE(self):
        path = self.path.split("?")[0].rstrip("/") or "/"
        if path.startswith("/exam/"):
            self._handle_delete(path[6:])
        else:
            self._json({"error": "not found"}, 404)

    def do_PATCH(self):
        path = self.path.split("?")[0].rstrip("/") or "/"
        if path.startswith("/exam/"):
            self._handle_patch_exam(path[6:])
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        if self.path == "/submit":
            self._handle_submit()
        elif self.path == "/shutdown":
            self._cancel_idle_timer()
            self._json({"ok": True})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
        elif self.path == "/import":
            self._handle_import()
        else:
            self._json({"error": "not found"}, 404)

    def _list_exams(self):
        exam_dir = self.server.exam_dir
        exams = []
        pattern = os.path.join(exam_dir, "ccaf-*.json")
        for fpath in sorted(glob.glob(pattern), reverse=True):
            if fpath.endswith("-result.json"):
                continue
            try:
                with open(fpath, encoding="utf-8") as fh:
                    data = json.load(fh)
            except (json.JSONDecodeError, OSError):
                continue
            exam_id = data.get("id", "")
            result_path = os.path.join(exam_dir, f"{exam_id}-result.json")
            result = None
            if os.path.exists(result_path):
                try:
                    with open(result_path, encoding="utf-8") as fh:
                        result = json.load(fh)
                except (json.JSONDecodeError, OSError):
                    pass
            exams.append({
                "id": exam_id,
                "name": data.get("name", exam_id),
                "generated_at": data.get("generated_at", ""),
                "scenarios": data.get("scenarios", []),
                "total": data.get("total", 60),
                "completed": result is not None,
                "verdict": result.get("verdict") if result else None,
                "scaled": result.get("scaled") if result else None,
            })
        self._json(exams)

    def _serve_json_file(self, fpath):
        if not os.path.exists(fpath):
            self._json({"error": "not found"}, 404)
            return
        try:
            with open(fpath, "rb") as fh:
                content = fh.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except OSError as e:
            self._json({"error": str(e)}, 500)

    def _serve_exam(self, exam_id):
        if not re.match(r"^[a-zA-Z0-9_-]+$", exam_id):
            self._json({"error": "invalid exam id"}, 400)
            return
        self._serve_json_file(os.path.join(self.server.exam_dir, f"{exam_id}.json"))

    def _serve_result(self, exam_id):
        if not re.match(r"^[a-zA-Z0-9_-]+$", exam_id):
            self._json({"error": "invalid exam id"}, 400)
            return
        self._serve_json_file(os.path.join(self.server.exam_dir, f"{exam_id}-result.json"))

    def _handle_submit(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            result = json.loads(body)
        except (ValueError, json.JSONDecodeError) as e:
            self._json({"error": str(e)}, 400)
            return

        exam_id = result.get("exam_id", "")
        if not re.match(r"^[a-zA-Z0-9_-]+$", exam_id):
            self._json({"error": "invalid exam_id"}, 400)
            return

        result_path = os.path.join(self.server.exam_dir, f"{exam_id}-result.json")
        try:
            with open(result_path, "w", encoding="utf-8") as fh:
                json.dump(result, fh, indent=2, ensure_ascii=False)
        except OSError as e:
            self._json({"error": str(e)}, 500)
            return

        self._json({"ok": True})
        self._cancel_idle_timer()
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def _handle_delete(self, exam_id):
        if not re.match(r"^[a-zA-Z0-9_-]+$", exam_id):
            self._json({"error": "invalid exam id"}, 400)
            return
        exam_path = os.path.join(self.server.exam_dir, f"{exam_id}.json")
        if not os.path.exists(exam_path):
            self._json({"error": "not found"}, 404)
            return
        os.remove(exam_path)
        result_path = os.path.join(self.server.exam_dir, f"{exam_id}-result.json")
        if os.path.exists(result_path):
            os.remove(result_path)
        self._json({"ok": True})

    def _handle_patch_exam(self, exam_id):
        if not re.match(r"^[a-zA-Z0-9_-]+$", exam_id):
            self._json({"error": "invalid exam id"}, 400)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            updates = json.loads(body)
        except (ValueError, json.JSONDecodeError) as e:
            self._json({"error": str(e)}, 400)
            return
        new_name = updates.get("name", "")
        if not isinstance(new_name, str) or not new_name.strip():
            self._json({"error": "name must be a non-empty string"}, 400)
            return
        exam_path = os.path.join(self.server.exam_dir, f"{exam_id}.json")
        if not os.path.exists(exam_path):
            self._json({"error": "not found"}, 404)
            return
        try:
            with open(exam_path, encoding="utf-8") as fh:
                exam = json.load(fh)
            exam["name"] = new_name.strip()
            with open(exam_path, "w", encoding="utf-8") as fh:
                json.dump(exam, fh, indent=2, ensure_ascii=False)
        except (OSError, json.JSONDecodeError) as e:
            self._json({"error": str(e)}, 500)
            return
        self._json({"ok": True})

    def _reveal_folder(self):
        import platform
        import subprocess
        exam_dir = self.server.exam_dir
        os.makedirs(exam_dir, exist_ok=True)
        system = platform.system()
        try:
            if system == "Darwin":
                subprocess.Popen(["open", exam_dir])
            elif system == "Linux":
                subprocess.Popen(["xdg-open", exam_dir])
            else:
                self._json({"error": "unsupported platform"}, 400)
                return
            self._json({"ok": True})
        except OSError as e:
            self._json({"error": str(e)}, 500)

    def _handle_import(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            exam = json.loads(body)
        except (ValueError, json.JSONDecodeError) as e:
            self._json({"error": str(e)}, 400)
            return

        exam_id = exam.get("id", "")
        if not re.match(r"^[a-zA-Z0-9_-]+$", exam_id):
            self._json({"error": "invalid or missing exam id"}, 400)
            return

        if not isinstance(exam.get("sections"), list) or not exam.get("total"):
            self._json({"error": "invalid exam: missing sections or total"}, 400)
            return

        # Validate every question the browser will score. A missing key/options/stem
        # imports silently and then mis-scores (decodeKey yields '?', every answer
        # marked wrong) with no error — so reject it at the boundary instead.
        for section in exam["sections"]:
            for q in section.get("questions", []):
                missing = [f for f in ("key", "options", "stem") if not q.get(f)]
                if missing:
                    self._json({
                        "error": f"invalid exam: question {q.get('n', '?')} "
                                 f"missing {', '.join(missing)}"
                    }, 400)
                    return

        out_path = os.path.join(self.server.exam_dir, f"{exam_id}.json")
        if os.path.exists(out_path):
            self._json({"error": "exam already exists", "id": exam_id}, 409)
            return

        try:
            os.makedirs(self.server.exam_dir, exist_ok=True)
            with open(out_path, "w", encoding="utf-8") as fh:
                json.dump(exam, fh, indent=2, ensure_ascii=False)
        except OSError as e:
            self._json({"error": str(e)}, 500)
            return

        self._json({"ok": True, "id": exam_id})


def cmd_serve(args):
    server = HTTPServer(("127.0.0.1", args.port), ExamHandler)
    server.exam_dir = os.path.expanduser(args.exam_dir)
    server.plugin_root = args.plugin_root
    server._idle_timer = None
    # Arm immediately so a browser that closes before the first heartbeat
    # (which fires after 10 s) still triggers shutdown.
    server._idle_timer = threading.Timer(
        IDLE_TIMEOUT,
        lambda: threading.Thread(target=server.shutdown, daemon=True).start(),
    )
    server._idle_timer.start()
    print(f"CCAF exam server listening on http://localhost:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="mode", required=True)

    exp = sub.add_parser("export", help="Convert exam files to JSON")
    exp.add_argument("--exam-id",   required=True, help="Exam identifier (e.g. ccaf-20260619-143022)")
    exp.add_argument("--exam-src",  required=True, help="Path prefix for exam files (without .md suffix)")
    exp.add_argument("--exam-dir",  required=True, help="Directory to write the JSON into")
    exp.add_argument("--name",      default="",    help="Human-readable display name for this exam")

    srv = sub.add_parser("serve", help="Run the HTTP server")
    srv.add_argument("--port",        type=int, default=8765, help="TCP port (default 8765)")
    srv.add_argument("--exam-dir",    required=True, help="Directory containing exam JSON files")
    srv.add_argument("--plugin-root", required=True, help="Plugin root directory (for app.html)")

    args = parser.parse_args()
    args.exam_dir = os.path.expanduser(args.exam_dir)

    if args.mode == "export":
        cmd_export(args)
    else:
        cmd_serve(args)


if __name__ == "__main__":
    main()

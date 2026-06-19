#!/usr/bin/env python3
"""
Tests for web/server.py — parser functions and HTTP routes.
Run: python3 scripts/tests/server.test.py
"""

import http.client
import json
import os
import sys
import tempfile
import threading
import time
import unittest
from http.server import HTTPServer

REPO_ROOT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
)
sys.path.insert(0, os.path.join(REPO_ROOT, 'web'))
import server as srv  # noqa: E402  (must come after sys.path tweak)

# ── Fixtures ──────────────────────────────────────────────────────────────────

QUESTIONS_FIXTURE = """\
---
status: in_progress
total: 4
scenarios: s1,s2
next_index: 1
---
[[CASE:s1]]
title: Scenario One
brief: Brief for scenario one.
[[Q1]]
domain: D1
scenario: s1
source: generated
id: gen-01
stem: What is the answer to Q1?
A) Apple
B) Banana
C) Cherry
D) Date
answer_key: B
user_answer:
[[Q2]]
domain: D2
scenario: s1
source: generated
id: gen-02
stem: What is the answer to Q2?
A) Alpha
B) Beta
C) Gamma
D) Delta
answer_key: A
user_answer:
[[CASE:s2]]
title: Scenario Two
brief: Brief for scenario two.
[[Q3]]
domain: D3
scenario: s2
source: generated
id: gen-03
stem: What is the answer to Q3?
A) One
B) Two
C) Three
D) Four
answer_key: C
user_answer:
[[Q4]]
domain: D4
scenario: s2
source: generated
id: gen-04
stem: What is the answer to Q4?
A) Red
B) Blue
C) Green
D) Yellow
answer_key: D
user_answer:
"""

ANSWERS_FIXTURE = """\
---
status: in_progress
total: 4
---
1 D1 B -
2 D2 A -
3 D3 C -
4 D4 D -
"""


# ── Server helpers ────────────────────────────────────────────────────────────

def start_server(exam_dir):
    """Start an ExamHandler server on an OS-assigned ephemeral port."""
    s = HTTPServer(('127.0.0.1', 0), srv.ExamHandler)
    s.exam_dir = exam_dir
    s.plugin_root = REPO_ROOT
    port = s.server_address[1]
    threading.Thread(target=s.serve_forever, daemon=True).start()
    for _ in range(40):
        try:
            c = http.client.HTTPConnection('127.0.0.1', port, timeout=1)
            c.request('GET', '/ping')
            resp = c.getresponse()
            c.close()
            if resp.status == 200:
                return s, port
        except Exception:
            pass
        time.sleep(0.1)
    raise RuntimeError('Test server did not start in time')


def http_request(method, path, body=None, port=None):
    c = http.client.HTTPConnection('127.0.0.1', port, timeout=5)
    headers = {}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers = {
            'Content-Type': 'application/json',
            'Content-Length': str(len(data)),
        }
    c.request(method, path, body=data, headers=headers)
    resp = c.getresponse()
    status = resp.status
    content_type = resp.getheader('Content-Type', '')
    body_bytes = resp.read()
    c.close()
    return status, content_type, body_bytes


# ── Parser tests ──────────────────────────────────────────────────────────────

class TestParseQuestionsFile(unittest.TestCase):
    def setUp(self):
        fd, self.path = tempfile.mkstemp(suffix='.md')
        os.write(fd, QUESTIONS_FIXTURE.encode())
        os.close(fd)

    def tearDown(self):
        os.unlink(self.path)

    def test_total_and_scenarios(self):
        total, scenarios, _, _ = srv.parse_questions_file(self.path)
        self.assertEqual(total, 4)
        self.assertEqual(scenarios, ['s1', 's2'])

    def test_question_count(self):
        _, _, _, questions = srv.parse_questions_file(self.path)
        self.assertEqual(len(questions), 4)

    def test_question_fields(self):
        _, _, _, questions = srv.parse_questions_file(self.path)
        q = questions[0]
        self.assertEqual(q['n'], 1)
        self.assertEqual(q['domain'], 'D1')
        self.assertEqual(q['scenario'], 's1')
        self.assertEqual(q['stem'], 'What is the answer to Q1?')
        self.assertEqual(q['options']['A'], 'Apple')
        self.assertEqual(q['options']['B'], 'Banana')

    def test_case_metadata(self):
        _, _, cases, _ = srv.parse_questions_file(self.path)
        self.assertEqual(cases['s1']['title'], 'Scenario One')
        self.assertEqual(cases['s1']['brief'], 'Brief for scenario one.')
        self.assertEqual(cases['s2']['title'], 'Scenario Two')

    def test_scenario_assignment(self):
        _, _, _, questions = srv.parse_questions_file(self.path)
        self.assertEqual(questions[0]['scenario'], 's1')
        self.assertEqual(questions[2]['scenario'], 's2')


class TestParseAnswersFile(unittest.TestCase):
    def setUp(self):
        fd, self.path = tempfile.mkstemp(suffix='.md')
        os.write(fd, ANSWERS_FIXTURE.encode())
        os.close(fd)

    def tearDown(self):
        os.unlink(self.path)

    def test_keys_parsed(self):
        keys = srv.parse_answers_file(self.path)
        self.assertEqual(keys, {1: 'B', 2: 'A', 3: 'C', 4: 'D'})

    def test_only_valid_key_letters(self):
        keys = srv.parse_answers_file(self.path)
        for k, v in keys.items():
            self.assertIsInstance(k, int)
            self.assertIn(v, 'ABCD')


# ── HTTP route tests ──────────────────────────────────────────────────────────

class TestHTTPRoutes(unittest.TestCase):
    """Shared server instance for all non-submit route tests."""

    @classmethod
    def setUpClass(cls):
        cls.exam_dir = tempfile.mkdtemp()
        cls.server, cls.port = start_server(cls.exam_dir)

    @classmethod
    def tearDownClass(cls):
        try:
            cls.server.shutdown()
            cls.server.server_close()
        except Exception:
            pass

    def req(self, method, path, body=None):
        return http_request(method, path, body, port=self.__class__.port)

    def test_ping(self):
        status, _, body = self.req('GET', '/ping')
        self.assertEqual(status, 200)
        self.assertEqual(body, b'pong')

    def test_root_serves_html(self):
        status, ct, _ = self.req('GET', '/')
        self.assertEqual(status, 200)
        self.assertIn('text/html', ct)

    def test_exams_returns_list(self):
        status, _, body = self.req('GET', '/exams')
        self.assertEqual(status, 200)
        self.assertIsInstance(json.loads(body), list)

    def test_exam_not_found(self):
        status, _, _ = self.req('GET', '/exam/no-such-exam')
        self.assertEqual(status, 404)

    def test_result_not_found(self):
        status, _, _ = self.req('GET', '/result/no-such-exam')
        self.assertEqual(status, 404)

    def test_invalid_exam_id_rejected(self):
        status, _, _ = self.req('GET', '/exam/bad..id')
        self.assertEqual(status, 400)

    def test_invalid_result_id_rejected(self):
        status, _, _ = self.req('GET', '/result/bad..id')
        self.assertEqual(status, 400)

    def test_unknown_route_404(self):
        status, _, _ = self.req('GET', '/no-such-route')
        self.assertEqual(status, 404)


class TestSubmit(unittest.TestCase):
    """Each test gets its own server instance — POST /submit triggers shutdown."""

    def setUp(self):
        self.exam_dir = tempfile.mkdtemp()
        self.server, self.port = start_server(self.exam_dir)

    def tearDown(self):
        try:
            self.server.shutdown()
            self.server.server_close()
        except Exception:
            pass

    def req(self, method, path, body=None):
        return http_request(method, path, body, port=self.port)

    def test_submit_writes_result_file(self):
        exam_id = 'ccaf-submit-test'
        with open(os.path.join(self.exam_dir, f'{exam_id}.json'), 'w') as fh:
            json.dump({'id': exam_id, 'sections': [], 'total': 1}, fh)

        result = {
            'exam_id': exam_id,
            'correct': 1,
            'total': 1,
            'scaled': 115,
            'verdict': 'FAIL',
            'per_domain': {},
            'answers': {'1': 'A'},
        }
        status, _, body = self.req('POST', '/submit', result)
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(body).get('ok'))

        result_path = os.path.join(self.exam_dir, f'{exam_id}-result.json')
        self.assertTrue(os.path.exists(result_path))

    def test_submit_invalid_exam_id_rejected(self):
        status, _, _ = self.req('POST', '/submit', {'exam_id': '../bad', 'correct': 0, 'total': 1})
        self.assertEqual(status, 400)


if __name__ == '__main__':
    unittest.main(verbosity=2)

/**
 * Remark plugin: converts ```mermaid code blocks into
 * <pre class="mermaid"> tags that mermaid.js renders client-side.
 */
export default function remarkMermaid() {
  return (tree) => {
    walkTree(tree);
  };
}

function walkTree(node) {
  if (!node.children) return;

  for (let i = 0; i < node.children.length; i++) {
    const child = node.children[i];
    if (child.type === 'code' && child.lang === 'mermaid') {
      node.children[i] = {
        type: 'html',
        value: `<pre class="mermaid">${escapeHtml(child.value)}</pre>`,
      };
    } else {
      walkTree(child);
    }
  }
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

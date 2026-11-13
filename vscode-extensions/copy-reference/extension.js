// Copy the editor's selected lines as a grep-style reference to them, e.g. `src/main.go:12` for one line or
// `src/main.go:12-18` for several, to paste anywhere (e.g. a Claude Code session or a doc). The path is relative to the
// workspace folder (absolute for a file outside it), or always absolute if the command's args are
// `{ "absolute": true }`. With no selection, the cursor's line is used. Each selection (multiple cursors) gets its own
// line. Bound in keybindings.json.
const vscode = require('vscode');

function activate(context) {
  const command = vscode.commands.registerTextEditorCommand('copyReference.copy', async (editor, _edit, args) => {
    const uri = editor.document.uri;
    const path = args?.absolute ? uri.fsPath : vscode.workspace.asRelativePath(uri, false);
    const selections = [...editor.selections].sort((a, b) => a.start.line - b.start.line);
    const references = [];
    for (const selection of selections) {
      let lastLine = selection.end.line;
      // A selection of whole lines (e.g. made with shift+down) ends at the start of the next line, which isn't
      // selected.
      if (selection.end.character === 0 && lastLine > selection.start.line) {
        lastLine--;
      }
      const start = selection.start.line + 1;
      const end = lastLine + 1;
      const reference = start === end ? `${path}:${start}` : `${path}:${start}-${end}`;
      if (!references.includes(reference)) {
        references.push(reference);
      }
    }
    await vscode.env.clipboard.writeText(references.join('\n'));
    vscode.window.setStatusBarMessage(`Copied ${references.join(', ')}`, 3000);
  });
  context.subscriptions.push(command);
}

module.exports = { activate };

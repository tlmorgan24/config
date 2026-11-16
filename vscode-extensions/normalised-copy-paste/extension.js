// Make copy-paste in VS Code "indentation-aware" as follows:
//
// By default, copying and pasting in VS code preserves all that is copied. E.g. if you have
// \txxx\n\tyyy, then selecting it all, copying, and pasting will literally paste a tab, then xxx,
// then a newline, then a tab, then yyy. However, this is often undesirable, because it fails to
// appreciate the indentation context of where you are pasting. E.g. if you paste it when your
// cursor is at indent level 3 (\t\t\t|), then you end up with \t\t\t\txxx\n\tyyy. I.e., the two
// lines which were originally at the same indent level are now at totally different ones. This
// extension solves the problem with the following approach:
//
// 1. There are two common cases: either the selection starts at the very start of the line, or it
// starts at the first non-whitespace. Normalise both of these so they both act as if all the
// line’s leading whitespace was selected (if a selection instead starts AFTER the first
// non-whitespace, we do not intervene).
// 2. Copy what you get from stripping common leading whitespace from every line of the normalised
// selection.
// 3. On paste, if there is only whitespace before the cursor, get that whitespace (e.g. \t\t) and
// apply it to every line of what is pasted EXCEPT entirely blank lines. Else (there is
// non-whitespace before the cursor), do not intervene.
//
// Full example: imagine \txxx\n\tyyy\n\t\tzzz. You select all three lines, copy (normalises to
// \txxx\n\tyyy\n\t\tzzz regardless whether you selected it with the first line’s
// leading \t or not ->
// common whitespace stripped to become xxx\nyyy\n\tzzz). Then, you move your cursor to a
// 3x-indented part of the codebase (i.e. \t\t\t|). After pasting, the three lines look like
// \t\t\txxx\n\t\t\tyyy\n\t\t\t\tzzz.

const vscode = require('vscode');

function activate(context) {
  const copy = vscode.commands.registerTextEditorCommand('normalisedCopyPaste.copy', async (editor) => {
    const texts = editor.selections.map((selection) => {
      let start = selection.start;
      const line = editor.document.lineAt(start.line).text;
      const firstNonWhitespace = line.search(/\S|$/);
      if (start.character === 0 || start.character === firstNonWhitespace) {
        start = start.with({ character: 0 });
      }
      return editor.document.getText(new vscode.Range(start, selection.end));
    });

    await vscode.env.clipboard.writeText(stripCommonIndent(texts.join('\n')));
  });

  const paste = vscode.commands.registerTextEditorCommand('normalisedCopyPaste.paste', async (editor) => {
    const text = await vscode.env.clipboard.readText();
    const replacements = editor.selections.map((selection) => {
      const position = selection.start;
      const linePrefix = editor.document.lineAt(position.line).text.slice(0, position.character);
      const indentation = /^[ \t]*$/.test(linePrefix) ? linePrefix : '';
      return { range: selection, text: addIndentation(text, indentation) };
    });

    await editor.edit((edit) => {
      for (const replacement of replacements) {
        edit.replace(replacement.range, replacement.text);
      }
    });
  });

  context.subscriptions.push(copy, paste);
}

function stripCommonIndent(text) {
  const lines = text.split('\n');
  const indents = lines
    .filter((line) => /\S/.test(line))
    .map((line) => line.match(/^[ \t]*/)[0].length);
  const commonIndent = indents.length > 0 ? Math.min(...indents) : 0;
  return lines.map((line) => (/\S/.test(line) ? line.slice(commonIndent) : line)).join('\n');
}

function addIndentation(text, indentation) {
  if (!indentation || !text.includes('\n')) {
    return text;
  }
  return text.replace(/\n(?=[^\n]*\S)/g, `\n${indentation}`);
}

module.exports = { activate };

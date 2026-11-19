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
// 1. If the selection starts anywhere before the first non-whitespace of its line, normalise it as
// if all the line's leading whitespace was selected (if a selection instead starts AFTER the first
// non-whitespace, do not intervene).
// 2. Copy what you get from stripping common leading whitespace from every line of the normalised
// selection.
// 3. On paste, if there is only whitespace before the cursor, get that whitespace (e.g. \t\t) and
// apply it to every line of what is pasted EXCEPT entirely blank lines. Else (there is
// non-whitespace before the cursor), do not intervene.
//
// Full example: imagine \txxx\n\tyyy\n\t\tzzz. You select all three lines, copy (normalises to
// \txxx\n\tyyy\n\t\tzzz regardless whether you selected it with the first line’s leading \t or not
// -> common whitespace stripped to become xxx\nyyy\n\tzzz). Then, you move your cursor to a
// 3x-indented part of the codebase (i.e. \t\t\t|). After pasting, the three lines look like
// \t\t\txxx\n\t\t\tyyy\n\t\t\t\tzzz.
//
// Comment support: the same applies "through" line-comment marks.
//
// - Copy: a selection starting anywhere at or before the first text after a comment marker counts
// as starting at the line's start. The comment marks stay in the clipboard text (so the copied text
// is still a comment). The common indent before the marks is stripped as usual, and so is
// the whitespace common to all text after the marks, leaving one space: "//    a\n//      b"
// is copied as "// a\n//   b".
// - Paste into code (only whitespace before the cursor): pasted as above, so it stays a comment.
// - Paste into a comment (only whitespace + comment marker + whitespace before the cursor): if
// every non-blank clipboard line is a comment, the markers are stripped first (so they are not
// duplicated), then the cursor's whole prefix (indent + marker + spacing) is applied to every
// following non-blank line. Blank lines get just the marker (no trailing whitespace), so paragraph
// breaks in comments are preserved.

const vscode = require('vscode');

// Regex sources for line-comment markers, by languageId. Languages not listed get no comment
// handling (so e.g. Markdown "# headings" are left alone).
const MARKER_SOURCE_BY_LANGUAGE = {
  go: '\\/\\/+',
  javascript: '\\/\\/+',
  javascriptreact: '\\/\\/+',
  typescript: '\\/\\/+',
  typescriptreact: '\\/\\/+',
  java: '\\/\\/+',
  c: '\\/\\/+',
  cpp: '\\/\\/+',
  csharp: '\\/\\/+',
  rust: '\\/\\/+',
  swift: '\\/\\/+',
  kotlin: '\\/\\/+',
  jsonc: '\\/\\/+',
  shellscript: '#+',
  bash: '#+',
  python: '#+',
  ruby: '#+',
  perl: '#+',
  yaml: '#+',
  toml: '#+',
  dockerfile: '#+',
  makefile: '#+',
  sql: '--',
  lua: '--',
  haskell: '--',
};

function markerSource(languageId) {
  return MARKER_SOURCE_BY_LANGUAGE[languageId] || null;
}

// Matches leading indent + marker (and nothing else).
function markerRegex(languageId) {
  const source = markerSource(languageId);
  return source ? new RegExp(`^[ \\t]*(?:${source})`) : null;
}

// Matches a line that is ONLY indent + marker + optional whitespace (i.e. the text before a cursor
// that is "at the start of a comment").
function commentPrefixOnlyRegex(languageId) {
  const source = markerSource(languageId);
  return source ? new RegExp(`^[ \\t]*(?:${source})[ \\t]*$`) : null;
}

function activate(context) {
  const copy = vscode.commands.registerTextEditorCommand('normalisedCopyPaste.copy', async (editor) => {
    const languageId = editor.document.languageId;
    const markerRe = markerRegex(languageId);

    const texts = editor.selections.map((selection) => {
      let start = selection.start;
      const line = editor.document.lineAt(start.line).text;
      const firstNonWhitespace = line.search(/\S|$/);
      let contentStart = firstNonWhitespace;
      if (markerRe) {
        const m = markerRe.exec(line);
        if (m) {
          contentStart = m[0].length + line.slice(m[0].length).match(/^[ \t]*/)[0].length;
        }
      }
      if (start.character === 0 || start.character === firstNonWhitespace || start.character <= contentStart) {
        start = start.with({ character: 0 });
      }
      return editor.document.getText(new vscode.Range(start, selection.end));
    });

    let copied = stripCommonIndent(texts.join('\n'));
    if (markerRe && stripCommentMarkers(copied, markerRe) !== null) {
      copied = normaliseCommentSpacing(copied, markerRe);
    }
    await vscode.env.clipboard.writeText(copied);
  });

  const paste = vscode.commands.registerTextEditorCommand('normalisedCopyPaste.paste', async (editor) => {
    const text = await vscode.env.clipboard.readText();
    const languageId = editor.document.languageId;
    const commentOnlyRe = commentPrefixOnlyRegex(languageId);
    const markerRe = markerRegex(languageId);

    const replacements = editor.selections.map((selection) => {
      const position = selection.start;
      const linePrefix = editor.document.lineAt(position.line).text.slice(0, position.character);

      if (/^[ \t]*$/.test(linePrefix)) {
        return { range: selection, text: addIndentation(text, linePrefix, '') };
      }
      if (commentOnlyRe && commentOnlyRe.test(linePrefix)) {
        // Already-commented clipboard text: drop its markers so they aren't duplicated.
        const uncommented = markerRe ? stripCommentMarkers(text, markerRe) : null;
        const body = uncommented !== null ? stripCommonIndent(uncommented) : text;
        const lineSuffix = editor.document.lineAt(selection.end.line).text.slice(selection.end.character);
        const trailingPrefix = /\S/.test(lineSuffix) ? linePrefix : '';
        // Blank pasted lines keep the marker (minus trailing whitespace) so paragraphs survive.
        return { range: selection, text: addIndentation(body, linePrefix, linePrefix.replace(/[ \t]+$/, ''), trailingPrefix) };
      }
      return { range: selection, text };
    });

    await editor.edit((edit) => {
      for (const replacement of replacements) {
        edit.replace(replacement.range, replacement.text);
      }
    });
  });

  context.subscriptions.push(copy, paste);
}

// If every non-blank line starts with a comment marker, returns the lines with indent + marker
// removed (marker-only lines become ''). Otherwise returns null. Used on paste into a comment.
function stripCommentMarkers(text, markerRe) {
  const lines = text.split('\n');
  let sawComment = false;
  const stripped = [];
  for (const line of lines) {
    if (!/\S/.test(line)) {
      stripped.push('');
      continue;
    }
    const m = markerRe.exec(line);
    if (!m) {
      return null;
    }
    sawComment = true;
    const rest = line.slice(m[0].length);
    stripped.push(/\S/.test(rest) ? rest : '');
  }
  return sawComment ? stripped.join('\n') : null;
}

// For a block where every non-blank line is a comment: strips the whitespace common to all the
// text after the markers, leaving a single space (so "//    a\n//      b" becomes "// a\n//   b").
// Marker-only lines are untouched and ignored when finding the common whitespace.
function normaliseCommentSpacing(text, markerRe) {
  const parsed = text.split('\n').map((line) => {
    const m = /\S/.test(line) ? markerRe.exec(line) : null;
    if (!m) {
      return { line, marker: null };
    }
    const rest = line.slice(m[0].length);
    return { line, marker: m[0], rest, gap: rest.match(/^[ \t]*/)[0].length };
  });
  const gaps = parsed.filter((p) => p.marker !== null && /\S/.test(p.rest)).map((p) => p.gap);
  const common = gaps.length > 0 ? Math.min(...gaps) : 0;
  return parsed
    .map((p) => {
      if (p.marker === null || !/\S/.test(p.rest)) {
        return p.marker === null ? p.line : p.marker;
      }
      return p.marker + (common > 0 ? ' ' : '') + p.rest.slice(common);
    })
    .join('\n');
}

function stripCommonIndent(text) {
  const lines = text.split('\n');
  const indents = lines
    .filter((line) => /\S/.test(line))
    .map((line) => line.match(/^[ \t]*/)[0].length);
  const commonIndent = indents.length > 0 ? Math.min(...indents) : 0;
  return lines.map((line) => (/\S/.test(line) ? line.slice(commonIndent) : line)).join('\n');
}

// Prefixes every line after the first. Non-blank lines get `indentation`. Blank lines get
// `blankPrefix` (if non-empty; e.g. the bare comment marker) or are left alone. A trailing empty
// string (text ending in a newline) gets `trailingPrefix` when existing text will follow it.
function addIndentation(text, indentation, blankPrefix, trailingPrefix = '') {
  if (!indentation || !text.includes('\n')) {
    return text;
  }
  const lines = text.split('\n');
  return lines
    .map((line, i) => {
      if (i === 0) {
        return line;
      }
      if (i === lines.length - 1 && line === '') {
        return trailingPrefix;
      }
      if (/\S/.test(line)) {
        return indentation + line;
      }
      if (blankPrefix) {
        return blankPrefix;
      }
      return line;
    })
    .join('\n');
}

module.exports = { activate };

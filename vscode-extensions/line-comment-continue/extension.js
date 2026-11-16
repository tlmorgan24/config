const vscode = require("vscode");

const commentPrefixes = {
  go: "//",
  shellscript: "#",
};

function bulletMarker(content) {
  const trimmed = content.trimStart();
  if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
    return { marker: trimmed.slice(0, 2), number: null };
  }

  let match = trimmed.match(/^\((\d+)\) /);
  if (match) {
    return { marker: match[0], number: Number(match[1]) };
  }
  match = trimmed.match(/^(\d+)([.)]) /);
  if (match) {
    return { marker: match[0], number: Number(match[1]) };
  }
  return null;
}

function parseCommentLine(line, prefix) {
  const match = line.match(new RegExp(`^(\\s*)${prefix.replace("/", "\\/")}(\\s*)(.*)$`));
  if (!match) {
    return null;
  }
  return {
    indentation: match[1],
    separator: match[2],
    content: match[3],
  };
}

function nextNumericMarker(marker, number) {
  if (marker.startsWith("(")) {
    return `(${number + 1}) `;
  }
  return `${number + 1}${marker.endsWith(") ") ? ") " : ". "}`;
}

function sameNumericList(marker, candidate) {
  if (!marker || marker.number === null || !candidate || candidate.number === null) {
    return false;
  }
  const markerShape = marker.marker.startsWith("(") ? "parenthesized" : marker.marker.endsWith(") ") ? ")" : ".";
  const candidateShape = candidate.marker.startsWith("(") ? "parenthesized" : candidate.marker.endsWith(") ") ? ")" : ".";
  return markerShape === candidateShape;
}

function bulletContext(document, lineNumber, prefix) {
  const line = document.lineAt(lineNumber).text;
  const comment = parseCommentLine(line, prefix);
  if (!comment) {
    return null;
  }

  const directBullet = bulletMarker(comment.content);
  if (directBullet) {
    return { comment, bullet: directBullet, separator: comment.separator };
  }

  for (let previousLineNumber = lineNumber - 1; previousLineNumber >= 0; previousLineNumber--) {
    const previousLine = parseCommentLine(document.lineAt(previousLineNumber).text, prefix);
    if (!previousLine || previousLine.indentation !== comment.indentation) {
      return null;
    }
    const previousBullet = bulletMarker(previousLine.content);
    if (previousBullet) {
      if (comment.separator.length === previousLine.separator.length + previousBullet.marker.length) {
        return {
          comment,
          bullet: previousBullet,
          separator: previousLine.separator,
        };
      }
      return null;
    }
  }
  return null;
}

function continuationFor(document, position) {
  const prefix = commentPrefixes[document.languageId];
  if (!prefix) {
    return null;
  }

  const line = document.lineAt(position.line).text;
  const context = bulletContext(document, position.line, prefix);
  const comment = parseCommentLine(line, prefix);
  if (!comment || position.character < comment.indentation.length + prefix.length) {
    return null;
  }

  const contentAtCursor = line.slice(comment.indentation.length + prefix.length);
  const bullet = context ? context.bullet : bulletMarker(contentAtCursor);
  let continuation = `${comment.indentation}${prefix}${comment.separator}`;
  let numericBullet = null;

  if (bullet) {
    const separator = context ? context.separator : comment.separator;
    continuation = `${comment.indentation}${prefix}${separator}${bullet.marker}`;
    if (bullet.number !== null) {
      numericBullet = bullet;
      continuation = `${comment.indentation}${prefix}${separator}${nextNumericMarker(bullet.marker, bullet.number)}`;
    }
  }

  return { continuation, numericBullet };
}

async function continueComment() {
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.selection.isEmpty === false) {
    return vscode.commands.executeCommand("default:type", { text: "\n" });
  }

  const position = editor.selection.active;
  const continuation = continuationFor(editor.document, position);
  if (!continuation) {
    return vscode.commands.executeCommand("default:type", { text: "\n" });
  }

  const prefix = commentPrefixes[editor.document.languageId];
  const line = editor.document.lineAt(position.line);
  const comment = parseCommentLine(line.text, prefix);
  const eol = editor.document.eol === vscode.EndOfLine.CRLF ? "\r\n" : "\n";
  const edits = [{ range: new vscode.Range(position, position), text: `${eol}${continuation.continuation}` }];

  if (continuation.numericBullet) {
    const current = continuation.numericBullet;
    for (let lineNumber = position.line + 1; lineNumber < editor.document.lineCount; lineNumber++) {
      const nextLine = editor.document.lineAt(lineNumber);
      const nextComment = parseCommentLine(nextLine.text, prefix);
      if (!nextComment || nextComment.indentation !== comment.indentation) {
        break;
      }
      const nextBullet = bulletMarker(nextComment.content);
      if (!nextBullet) {
        continue;
      }
      if (!sameNumericList(current, nextBullet)) {
        break;
      }
      const markerStart = nextLine.text.length - nextComment.content.length + nextComment.content.search(/\S/);
      const markerLength = nextBullet.marker.length;
      edits.push({
        range: new vscode.Range(lineNumber, markerStart, lineNumber, markerStart + markerLength),
        text: nextNumericMarker(nextBullet.marker, nextBullet.number),
      });
    }
  }

  const applied = await editor.edit((builder) => {
    for (const textEdit of edits) {
      builder.replace(textEdit.range, textEdit.text);
    }
  });
  if (!applied) {
    throw new Error("Line Comment Continue could not apply the edit");
  }
}

function activate(context) {
  context.subscriptions.push(vscode.commands.registerCommand("lineCommentContinue.enter", continueComment));
}

function deactivate() {}

module.exports = {
  activate,
  deactivate,
  bulletMarker,
  continuationFor,
};

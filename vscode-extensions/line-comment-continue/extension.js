const vscode = require("vscode");

const commentPrefixes = {
  go: "//",
  shellscript: "#",
  python: "#",
  javascript: "//",
  javascriptreact: "//",
  typescript: "//",
  typescriptreact: "//",
  json: "//",
  jsonc: "//",
};

const lineRegexes = new Map();

function lineRegex(prefix) {
  let regex = lineRegexes.get(prefix);
  if (!regex) {
    const escaped = prefix.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
    regex = new RegExp(`^(\\s*)${escaped}(\\s*)(.*)$`);
    lineRegexes.set(prefix, regex);
  }
  return regex;
}

function parseCommentLine(line, prefix) {
  const match = line.match(lineRegex(prefix));
  if (!match) {
    return null;
  }
  return {
    indentation: match[1],
    separator: match[2],
    content: match[3],
  };
}

// Recognises `-`, `*`, `(1)`, `1)` and `1.`, followed by whitespace and text or
// by nothing (a bare marker). `marker` includes all whitespace after the
// marker, so its length is the distance from the marker to the text. `empty`
// is true if there is no text after the marker.
function bulletMarker(content) {
  const trimmed = content.trimStart();
  let match = trimmed.match(/^([-*])(\s+|$)/);
  let core;
  let gap;
  let number = null;
  if (match) {
    [, core, gap] = match;
  } else if ((match = trimmed.match(/^(\(\d+\))(\s+|$)/))) {
    [, core, gap] = match;
    number = Number(core.slice(1, -1));
  } else if ((match = trimmed.match(/^(\d+[.)])(\s+|$)/))) {
    [, core, gap] = match;
    number = Number(core.slice(0, -1));
  } else {
    return null;
  }
  return {
    marker: core + gap,
    core,
    gap,
    number,
    empty: trimmed.slice(core.length + gap.length) === "",
  };
}

function numericShape(core) {
  if (core.startsWith("(")) {
    return "parenthesized";
  }
  return core.endsWith(")") ? ")" : ".";
}

function renumberedCore(bullet, number) {
  if (bullet.core.startsWith("(")) {
    return `(${number})`;
  }
  return `${number}${bullet.core.slice(-1)}`;
}

function nextNumericMarker(marker, number) {
  const core = marker.trimEnd();
  const gap = marker.slice(core.length) || " ";
  return `${renumberedCore({ core }, number + 1)}${gap}`;
}

function sameNumericList(marker, candidate) {
  if (!marker || marker.number === null || !candidate || candidate.number === null) {
    return false;
  }
  return numericShape(marker.core) === numericShape(candidate.core);
}

// Finds the bullet that a line belongs to: either the line itself is a bullet,
// or it is a continuation line, i.e. directly below the bullet (or other
// continuation lines) with its text aligned to the bullet's text. A blank
// comment line, or a line at another alignment, ends the chain.
function bulletContext(document, lineNumber, prefix) {
  const comment = parseCommentLine(document.lineAt(lineNumber).text, prefix);
  if (!comment) {
    return null;
  }

  const directBullet = bulletMarker(comment.content);
  if (directBullet) {
    return { comment, bullet: directBullet, separator: comment.separator, direct: true };
  }
  if (comment.content === "") {
    return null;
  }

  for (let previousLineNumber = lineNumber - 1; previousLineNumber >= 0; previousLineNumber--) {
    const previousLine = parseCommentLine(document.lineAt(previousLineNumber).text, prefix);
    if (!previousLine || previousLine.indentation !== comment.indentation || previousLine.content === "") {
      return null;
    }
    const previousBullet = bulletMarker(previousLine.content);
    if (previousBullet) {
      if (comment.separator.length === previousLine.separator.length + previousBullet.marker.length) {
        return { comment, bullet: previousBullet, separator: previousLine.separator, direct: false };
      }
      return null;
    }
    if (previousLine.separator.length !== comment.separator.length) {
      return null;
    }
  }
  return null;
}

// Whether the given line is a (non-bullet) continuation line of a bullet whose
// text starts at textLevel.
function continuesBullet(document, lineNumber, prefix, indentation, textLevel) {
  if (lineNumber >= document.lineCount) {
    return false;
  }
  const comment = parseCommentLine(document.lineAt(lineNumber).text, prefix);
  return Boolean(
    comment &&
      comment.indentation === indentation &&
      comment.content !== "" &&
      !bulletMarker(comment.content) &&
      comment.separator.length === textLevel,
  );
}

// When a bullet's marker changes width (e.g. 9. -> 10.), the text moves, and
// the continuation lines below it must move too or they stop being part of it.
function shiftEdits(document, prefix, startLine, indentation, oldTextLevel, delta) {
  const edits = [];
  for (let lineNumber = startLine; lineNumber < document.lineCount; lineNumber++) {
    if (!continuesBullet(document, lineNumber, prefix, indentation, oldTextLevel)) {
      break;
    }
    const comment = parseCommentLine(document.lineAt(lineNumber).text, prefix);
    const start = comment.indentation.length + prefix.length;
    const separator =
      delta > 0
        ? comment.separator + " ".repeat(delta)
        : comment.separator.slice(0, Math.max(0, comment.separator.length + delta));
    edits.push({ start: [lineNumber, start], end: [lineNumber, start + comment.separator.length], text: separator });
  }
  return edits;
}

// Numbers the later siblings of a numeric list consecutively, starting from
// firstNumber. Nested (more indented) items and continuation lines are skipped,
// blank comments do not end the list, and it stops at anything else at the
// list's own indentation or less.
function renumberEdits(document, prefix, startLine, list, firstNumber) {
  const edits = [];
  let number = firstNumber;
  for (let lineNumber = startLine; lineNumber < document.lineCount; lineNumber++) {
    const comment = parseCommentLine(document.lineAt(lineNumber).text, prefix);
    if (!comment || comment.indentation !== list.indentation) {
      break;
    }
    if (comment.content === "") {
      continue;
    }
    const level = comment.separator.length;
    if (level > list.markerLevel) {
      continue;
    }
    if (level < list.markerLevel) {
      break;
    }
    const bullet = bulletMarker(comment.content);
    if (!bullet || !sameNumericList(list.bullet, bullet)) {
      break;
    }
    const core = renumberedCore(bullet, number);
    if (core !== bullet.core) {
      const markerStart = comment.indentation.length + prefix.length + comment.separator.length;
      edits.push({
        start: [lineNumber, markerStart],
        end: [lineNumber, markerStart + bullet.core.length],
        text: core,
      });
      const delta = core.length - bullet.core.length;
      if (delta !== 0) {
        edits.push(
          ...shiftEdits(document, prefix, lineNumber + 1, comment.indentation, level + bullet.marker.length, delta),
        );
      }
    }
    number++;
  }
  return edits;
}

// Reuse the first following paragraph's indentation if it is deeper than the
// intro's text. Blank comments separate paragraphs without ending an intro.
function colonSeparator(document, lineNumber, prefix, comment, textSeparator) {
  for (let nextLine = lineNumber + 1; nextLine < document.lineCount; nextLine++) {
    const next = parseCommentLine(document.lineAt(nextLine).text, prefix);
    if (!next || next.indentation !== comment.indentation) {
      break;
    }
    if (next.content === "") {
      continue;
    }
    if (next.separator.length > textSeparator.length) {
      return next.separator;
    }
    break;
  }
  const indentSize = vscode.workspace
    .getConfiguration("lineCommentContinue", document.uri)
    .get("indentSize", 2);
  return textSeparator + " ".repeat(indentSize);
}

function continuationFor(document, position) {
  const prefix = commentPrefixes[document.languageId];
  if (!prefix) {
    return null;
  }

  const line = document.lineAt(position.line).text;
  const comment = parseCommentLine(line, prefix);
  if (!comment || position.character < comment.indentation.length + prefix.length) {
    return null;
  }

  const context = bulletContext(document, position.line, prefix);
  const start = `${comment.indentation}${prefix}`;
  if (
    context && context.direct &&
    position.character < start.length + context.separator.length + context.bullet.marker.length
  ) {
    return null;
  }
  const atEnd = line.slice(position.character).trim() === "";
  if (atEnd && comment.content.trimEnd().endsWith(":")) {
    const textSeparator = context && context.direct
      ? context.separator + " ".repeat(context.bullet.marker.length)
      : comment.separator;
    return {
      continuation: start + colonSeparator(document, position.line, prefix, comment, textSeparator),
      numericBullet: null,
    };
  }
  if (!context) {
    return { continuation: `${start}${comment.separator}`, numericBullet: null };
  }

  const { bullet } = context;
  const textLevel = context.separator.length + bullet.marker.length;
  const numeric = bullet.number !== null ? bullet : null;

  // Enter on a bullet with no text removes the marker, to leave the list.
  if (context.direct && bullet.empty && atEnd) {
    return { continuation: null, emptyBullet: true, numericBullet: numeric, context };
  }

  // Enter at the end of a bullet that has continuation lines below it must not
  // create a new marker directly above them: the formatter would pull them into
  // it. Just keep the text alignment.
  if (atEnd && continuesBullet(document, position.line + 1, prefix, comment.indentation, textLevel)) {
    return {
      continuation: `${start}${context.separator}${" ".repeat(bullet.marker.length)}`,
      numericBullet: null,
      context,
    };
  }

  if (numeric) {
    return {
      continuation: `${start}${context.separator}${nextNumericMarker(bullet.marker, bullet.number)}`,
      numericBullet: numeric,
      context,
    };
  }
  return {
    continuation: `${start}${context.separator}${bullet.core}${bullet.gap || " "}`,
    numericBullet: null,
    context,
  };
}

// Plans the edits for Enter. Positions are [line, character] pairs.
function planEnter(document, position) {
  const result = continuationFor(document, position);
  if (!result) {
    return null;
  }

  const prefix = commentPrefixes[document.languageId];
  const line = document.lineAt(position.line).text;
  const comment = parseCommentLine(line, prefix);
  const list = result.context && {
    indentation: comment.indentation,
    markerLevel: result.context.separator.length,
    bullet: result.context.bullet,
  };

  if (result.emptyBullet) {
    const markerStart = comment.indentation.length + prefix.length + comment.separator.length;
    const edits = [{ start: [position.line, markerStart], end: [position.line, line.length], text: "" }];
    if (result.numericBullet) {
      edits.push(...renumberEdits(document, prefix, position.line + 1, list, result.numericBullet.number));
    }
    return { edits, cursor: [position.line, markerStart] };
  }

  const eol = document.eol === vscode.EndOfLine.CRLF ? "\r\n" : "\n";
  const at = [position.line, position.character];
  const edits = [{ start: at, end: at, text: `${eol}${result.continuation}` }];
  if (result.numericBullet) {
    const bullet = result.numericBullet;
    const atEnd = line.slice(position.character).trim() === "";
    if (!atEnd) {
      // The text after the cursor becomes the new bullet's, so its continuation
      // lines must follow the new marker's width.
      const delta = nextNumericMarker(bullet.marker, bullet.number).length - bullet.marker.length;
      if (delta !== 0) {
        edits.push(
          ...shiftEdits(
            document,
            prefix,
            position.line + 1,
            comment.indentation,
            list.markerLevel + bullet.marker.length,
            delta,
          ),
        );
      }
    }
    edits.push(...renumberEdits(document, prefix, position.line + 1, list, bullet.number + 2));
  }
  return { edits, cursor: null };
}

// Plans the edits for Backspace directly after a bullet marker, which removes
// the whole marker. Returns null if Backspace should behave normally.
function planBackspace(document, position) {
  const prefix = commentPrefixes[document.languageId];
  if (!prefix) {
    return null;
  }

  const line = document.lineAt(position.line).text;
  const comment = parseCommentLine(line, prefix);
  const bullet = comment && bulletMarker(comment.content);
  if (!comment || !bullet) {
    return null;
  }

  const markerStart = comment.indentation.length + prefix.length + comment.separator.length;
  const markerEnd = markerStart + bullet.marker.length;
  if (position.character < markerEnd || /\S/.test(line.slice(markerEnd, position.character))) {
    return null;
  }

  const edits = [{ start: [position.line, markerStart], end: [position.line, markerEnd], text: "" }];
  if (bullet.number !== null) {
    const list = { indentation: comment.indentation, markerLevel: comment.separator.length, bullet };
    edits.push(...renumberEdits(document, prefix, position.line + 1, list, bullet.number));
  }
  return { edits, cursor: [position.line, markerStart] };
}

function toRange(edit) {
  return new vscode.Range(edit.start[0], edit.start[1], edit.end[0], edit.end[1]);
}

async function applyPlan(editor, plan) {
  const applied = await editor.edit((builder) => {
    for (const edit of plan.edits) {
      builder.replace(toRange(edit), edit.text);
    }
  });
  if (!applied) {
    throw new Error("Line Comment Continue could not apply the edit");
  }
  if (plan.cursor) {
    editor.selection = new vscode.Selection(plan.cursor[0], plan.cursor[1], plan.cursor[0], plan.cursor[1]);
  }
}

async function continueComment() {
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.selections.length !== 1 || editor.selection.isEmpty === false) {
    return vscode.commands.executeCommand("default:type", { text: "\n" });
  }

  const plan = planEnter(editor.document, editor.selection.active);
  if (!plan) {
    return vscode.commands.executeCommand("default:type", { text: "\n" });
  }
  return applyPlan(editor, plan);
}

async function removeBullet() {
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.selections.length !== 1 || editor.selection.isEmpty === false) {
    return vscode.commands.executeCommand("deleteLeft");
  }

  const plan = planBackspace(editor.document, editor.selection.active);
  if (!plan) {
    return vscode.commands.executeCommand("deleteLeft");
  }
  return applyPlan(editor, plan);
}

function activate(context) {
  context.subscriptions.push(vscode.commands.registerCommand("lineCommentContinue.enter", continueComment));
  context.subscriptions.push(vscode.commands.registerCommand("lineCommentContinue.backspace", removeBullet));
}

function deactivate() {}

module.exports = {
  activate,
  deactivate,
  bulletMarker,
  continuationFor,
  planEnter,
  planBackspace,
  removeBullet,
};

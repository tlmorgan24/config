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

function wordMarker(content) {
  const match = content.match(/^(\S+:)(\s+|$)|^(\S+ -)(\s+|$)/);
  if (!match) return null;
  const marker = match[0];
  return { marker, style: match[1] ? "word:" : "word-", bare: content.slice(marker.length).trim() === "" };
}

function markerStyle(content) {
  const bullet = bulletMarker(content);
  if (bullet) return bullet.number === null ? bullet.core : numericShape(bullet.core);
  return wordMarker(content)?.style || "ws";
}

// Identify all bullet forms in one scan, using the formatter's precedence.
// Standard markers stand alone; other forms need a colon-introduced list.
// Keep the owning item as well as its text alignment, so Enter can choose
// between a sibling and a continuation consistently for every bullet form.
function bulletContext(document, lineNumber, prefix) {
  const indentation = parseCommentLine(document.lineAt(lineNumber).text, prefix).indentation;
  const comments = [];
  let firstLine = lineNumber;
  while (firstLine > 0) {
    const previous = parseCommentLine(document.lineAt(firstLine - 1).text, prefix);
    if (!previous || previous.indentation !== indentation) break;
    firstLine--;
  }
  for (let i = firstLine; i < document.lineCount; i++) {
    const comment = parseCommentLine(document.lineAt(i).text, prefix);
    if (!comment || comment.indentation !== indentation) break;
    comments.push(comment);
  }
  const nextContent = (i) => {
    let j = i + 1;
    while (j < comments.length && comments[j].content === "") j++;
    return j;
  };
  const tableAt = (i) => {
    if (bulletMarker(comments[i].content)) return false;
    const count = comments[i].content.trimEnd().split(/\s{2,}/).length;
    if (count < 2) return false;
    for (let j = i + 1; j < comments.length; j++) {
      const next = comments[j];
      if (!next.content || bulletMarker(next.content)) return false;
      if (next.separator.length > comments[i].separator.length) continue;
      return next.separator.length === comments[i].separator.length &&
        next.content.trimEnd().split(/\s{2,}/).length === count;
    }
    return false;
  };
  const lists = [];
  let item = null;
  let table = null;
  let target = null;
  let followedByContent = false;
  for (let i = 0; i <= lineNumber - firstLine + 1 && i < comments.length; i++) {
    const comment = comments[i];
    const level = comment.separator.length;
    const style = markerStyle(comment.content);
    if (!comment.content) {
      item = null;
      table = null;
      continue;
    }
    while (lists.length && (level < lists.at(-1).level ||
      (level === lists.at(-1).level && style !== lists.at(-1).style))) lists.pop();
    const list = lists.at(-1);
    const standard = bulletMarker(comment.content);
    const word = wordMarker(comment.content);
    const next = comments[i + 1];
    const wsContinuation = item?.ws && level > item.separator.length;
    let markerLine = false;
    if (wsContinuation) {
      // Whitespace bullets absorb all deeper lines, even marker-looking text.
    } else if (standard || (list && level === list.level && style.startsWith("word"))) {
      const marker = standard || word;
      const nestedBelow = word?.bare && word.style === "word:" && next?.content &&
        next.separator.length > level && (bulletMarker(next.content) || wordMarker(next.content));
      markerLine = !standard && word.bare && !nestedBelow;
      item = {
        standard: Boolean(standard), bullet: marker, separator: comment.separator, line: i + firstLine,
        textSeparator: !standard && word.bare ? null : comment.separator + " ".repeat(
          standard?.empty ? standard.core.length + 1 : marker.marker.length),
        altSeparator: null, pullable: Boolean(standard?.empty), hasContent: !marker.empty,
        ownLine: markerLine, ws: false,
      };
      table = null;
    } else if (item?.pullable && level > item.separator.length) {
      item.pullable = false;
      item.hasContent = true;
      item.altSeparator = comment.separator;
    } else if (item?.ownLine && item.textSeparator === null && level > item.separator.length) {
      item.textSeparator = comment.separator;
    } else if (item && (item.textSeparator?.length === level || item.altSeparator?.length === level)) {
      // Aligned continuation of the current item.
    } else if (table && (level > table.level || (level === table.level &&
      comment.content.trimEnd().split(/\s{2,}/).length === table.count))) {
      item = null;
    } else if (tableAt(i)) {
      item = null;
      table = { level, count: comment.content.trimEnd().split(/\s{2,}/).length };
    } else if (list?.style === "ws" && level === list.level) {
      const ownLine = /^\S+\s*$/.test(comment.content);
      item = {
        standard: false, separator: comment.separator, ownLine, ws: !ownLine, line: i + firstLine,
        textSeparator: ownLine ? null : comment.separator + " ".repeat(level - list.introLevel),
      };
      table = null;
    } else if (!(item && !item.standard && !item.ownLine && level > item.separator.length)) {
      item = null;
      table = null;
    }

    const followingIndex = nextContent(i);
    const following = comments[followingIndex];
    const continuationBelow = followingIndex === i + 1 && item && following &&
      following.separator.length === item.textSeparator?.length && !bulletMarker(following.content);
    if (!table && !item?.ws && !markerLine && comment.content.trimEnd().endsWith(":") &&
      following && following.separator.length > level && !continuationBelow &&
      (markerStyle(following.content) !== "ws" || !tableAt(followingIndex))) {
      lists.push({ introLevel: level, level: following.separator.length, style: markerStyle(following.content) });
    }
    if (i === lineNumber - firstLine) target = item;
    if (i === lineNumber - firstLine + 1) followedByContent = Boolean(target && item === target);
  }
  return target ? { ...target, direct: target.line === lineNumber, followedByContent } : null;
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
function shiftEdits(document, prefix, startLine, indentation, oldTextLevel, delta, alternateLevel = null) {
  const edits = [];
  for (let lineNumber = startLine; lineNumber < document.lineCount; lineNumber++) {
    if (!continuesBullet(document, lineNumber, prefix, indentation, oldTextLevel) &&
      !(alternateLevel !== null && continuesBullet(document, lineNumber, prefix, indentation, alternateLevel))) {
      break;
    }
    const comment = parseCommentLine(document.lineAt(lineNumber).text, prefix);
    const start = comment.indentation.length + prefix.length;
    const targetLevel = Math.max(0, oldTextLevel + delta);
    const separator = targetLevel > comment.separator.length
      ? comment.separator + " ".repeat(targetLevel - comment.separator.length)
      : comment.separator.slice(0, targetLevel);
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
  const manual = context && !context.standard ? context : null;
  const start = `${comment.indentation}${prefix}`;
  if (
    context?.bullet && context.direct &&
    position.character < start.length + context.separator.length + context.bullet.marker.length
  ) {
    return null;
  }
  const atEnd = line.slice(position.character).trim() === "";
  if (atEnd && comment.content.trimEnd().endsWith(":")) {
    let textSeparator = comment.separator;
    if (manual && !(manual.ownLine && manual.separator === comment.separator)) {
      textSeparator = manual.textSeparator || comment.separator;
    } else if (context?.standard && context.direct) {
      textSeparator = context.separator + " ".repeat(context.bullet.marker.length);
    }
    return {
      continuation: start + colonSeparator(document, position.line, prefix, comment, textSeparator),
      numericBullet: null,
    };
  }
  if (manual) {
    const continueText = atEnd && manual.direct && manual.ownLine;
    return {
      continuation: start + (continueText
        ? manual.textSeparator || colonSeparator(document, position.line, prefix, comment, comment.separator)
        : manual.separator),
      numericBullet: null,
    };
  }
  if (!context) {
    return { continuation: `${start}${comment.separator}`, numericBullet: null };
  }

  const { bullet } = context;
  const numeric = bullet.number !== null ? bullet : null;

  // Enter on a bullet with no text removes the marker, to leave the list.
  if (context.direct && bullet.empty && !context.hasContent && atEnd) {
    return { continuation: null, emptyBullet: true, numericBullet: numeric, context };
  }

  // Enter directly after a bare marker starts its content. After text, Enter
  // starts a sibling instead, which takes ownership of remaining content below.
  if (atEnd && context.direct && bullet.empty && context.followedByContent) {
    // A bare marker remembers its first content line's original indentation.
    // Inserting new first content at another level would replace that accepted
    // alternative and could orphan the existing lines at the original level.
    return {
      continuation: start + context.altSeparator,
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
    // Remaining content belongs to the new sibling, whether the cursor splits
    // a line or sits at its end. Keep it aligned with the new marker's width.
    const delta = list.markerLevel + nextNumericMarker(bullet.marker, bullet.number).length -
      result.context.textSeparator.length;
    if (delta !== 0 || result.context.altSeparator) {
      edits.push(
        ...shiftEdits(
          document,
          prefix,
          position.line + 1,
          comment.indentation,
          result.context.textSeparator.length,
          delta,
          result.context.altSeparator?.length,
        ),
      );
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
  // Identify Enter explicitly: a paste can contain exactly the same newline
  // and prefix, but should reflow immediately rather than protect a boundary.
  const formatter = vscode.extensions?.getExtension("tlmorgan24.comment-wrap");
  let api;
  if (formatter) {
    try { api = formatter.isActive ? formatter.exports : await formatter.activate(); }
    catch { /* Continuation still works if the optional formatter cannot activate. */ }
  }
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.selections.length !== 1 || editor.selection.isEmpty === false) {
    return vscode.commands.executeCommand("default:type", { text: "\n" });
  }

  const plan = planEnter(editor.document, editor.selection.active);
  if (!plan) {
    return vscode.commands.executeCommand("default:type", { text: "\n" });
  }
  const newline = plan.edits.find((edit) => /[\r\n]/.test(edit.text));
  const range = newline && toRange(newline);
  const protection = newline && api?.protectEnter?.(editor.document, {
    rangeOffset: editor.document.offsetAt(range.start),
    rangeLength: editor.document.offsetAt(range.end) - editor.document.offsetAt(range.start),
    text: newline.text,
  });
  try { return await applyPlan(editor, plan); } finally { protection?.dispose(); }
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

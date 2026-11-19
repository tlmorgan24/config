const vscode = require("vscode");

// A document event expresses all its changes in pre-edit coordinates.
function moveOffset(offset, changes, right = true) {
  let delta = 0;
  for (const change of [...changes].sort((a, b) => a.rangeOffset - b.rangeOffset)) {
    const start = change.rangeOffset;
    const end = start + change.rangeLength;
    if (offset < start || (offset === start && !right)) break;
    if (offset <= end) return start + delta + (right ? change.text.length : 0);
    delta += change.text.length - change.rangeLength;
  }
  return offset + delta;
}

// Anchor edits to the actual comment characters, leaving words untouched.
// Changing only the gaps lets VS Code track the caret atomically with the
// edit, even when typing reaches the UI before its extension-host event.
function spacingChanges(before, after, base) {
  function characters(text) {
    const result = [];
    let offset = 0;
    for (const line of text.split("\n")) {
      const prefix = /^[ \t]*(?:\/\/|#)/.exec(line);
      if (!prefix) throw new Error("Live reflow expected standalone comments");
      for (let i = prefix[0].length; i < line.length; i++) {
        if (!/\s/.test(line[i])) result.push({ text: line[i], offset: offset + i });
      }
      offset += line.length + 1;
    }
    return result;
  }
  const oldChars = characters(before), newChars = characters(after);
  if (oldChars.length !== newChars.length || oldChars.some((char, i) => char.text !== newChars[i].text)) {
    throw new Error("Live reflow must preserve comment text");
  }
  const changes = [];
  let oldStart = 0, newStart = 0;
  for (let i = 0; i <= oldChars.length; i++) {
    let oldEnd = oldChars[i]?.offset ?? before.length;
    let newEnd = newChars[i]?.offset ?? after.length;
    // Preserve common whitespace as well, especially the active typing gap.
    let start = oldStart, replacementStart = newStart;
    while (start < oldEnd && replacementStart < newEnd && before[start] === after[replacementStart]) {
      start++; replacementStart++;
    }
    while (oldEnd > start && newEnd > replacementStart && before[oldEnd - 1] === after[newEnd - 1]) {
      oldEnd--; newEnd--;
    }
    if (start !== oldEnd || replacementStart !== newEnd) {
      changes.push({ rangeOffset: base + start, rangeLength: oldEnd - start, text: after.slice(replacementStart, newEnd) });
    }
    oldStart = (oldChars[i]?.offset ?? before.length) + 1;
    newStart = (newChars[i]?.offset ?? after.length) + 1;
  }
  return changes;
}

function sameChanges(actual, expected) {
  if (!expected || actual.length !== expected.length) return false;
  const ordered = (changes) => [...changes].sort((a, b) => a.rangeOffset - b.rangeOffset);
  const a = ordered(actual), b = ordered(expected);
  return a.every((change, i) => change.rangeOffset === b[i].rangeOffset && change.rangeLength === b[i].rangeLength && change.text === b[i].text);
}

class LiveReflow {
  constructor(run, loadConfig, reportError) {
    Object.assign(this, { run, loadConfig, reportError, states: new Map() });
  }

  state(document) {
    if (!this.states.has(document)) {
      this.states.set(document, { breaks: [], scope: null, affected: [], needsReflow: false, scheduledReflow: null, generation: 0, applying: false });
    }
    return this.states.get(document);
  }

  enabled(document) {
    return vscode.workspace.getConfiguration("commentWrap", document).get("liveReflow", true);
  }

  // Cancel queued work and invalidate in-flight results; no idle-time delay.
  cancel(state) {
    clearTimeout(state.scheduledReflow);
    state.scheduledReflow = null;
    state.afterApply = null;
    state.generation++;
  }

  reset(document) {
    const state = this.states.get(document);
    if (!state) return;
    this.cancel(state);
    state.breaks = [];
    state.scope = null;
    state.affected = [];
    state.needsReflow = false;
    state.enterChange = null;
  }

  // Enter and a one-newline paste can have identical document changes. The
  // continuation command identifies its exact planned edit before applying it.
  protectEnter(document, change) {
    const state = this.state(document);
    state.enterChange = change;
    return { dispose: () => { if (state.enterChange === change) state.enterChange = null; } };
  }

  changed(event) {
    const { document, contentChanges: changes } = event;
    if (!changes.length) return;
    const state = this.state(document);
    const ownEdit = state.applying && sameChanges(changes, state.expectedChanges);
    state.breaks = state.breaks.filter((at) => !changes.some((change) =>
      change.rangeLength && (ownEdit ? at > change.rangeOffset : at >= change.rangeOffset) && at < change.rangeOffset + change.rangeLength,
    )).map((at) => moveOffset(at, changes, !ownEdit));
    if (state.scope) {
      state.scope = { start: moveOffset(state.scope.start, changes, false), end: moveOffset(state.scope.end, changes) };
    }
    state.affected = state.affected.map((range) => ({
      start: moveOffset(range.start, changes, false), end: moveOffset(range.end, changes),
    }));
    if (ownEdit) return;
    this.cancel(state);
    // An undo must stay undone, rather than immediately getting normalized.
    if (event.reason !== undefined) return this.reset(document);
    const editor = vscode.window.activeTextEditor;
    if (!this.enabled(document) || editor?.document !== document || editor.selections.length !== 1) {
      return this.reset(document);
    }
    const newline = changes.length === 1 && state.enterChange && sameChanges(changes, [state.enterChange])
      && /^\r?\n[^\r\n]*$/.test(changes[0].text) ? changes[0] : null;
    if (!newline && changes.some((change) => /[\r\n]/.test(change.text))) {
      // Preserve multiline pastes and other bulk insertions exactly. Drop
      // pending work and its scope so typing or leaving cannot format the paste
      // later. Existing Enter boundaries still track their original paragraphs.
      state.affected = [];
      state.needsReflow = false;
      state.scope = null;
      state.enterChange = null;
      return;
    }
    // Spaces and tabs are an in-progress spacing/indentation edit. In
    // particular, after a bullet they change its alignment on every key; live
    // wrapping would repeatedly orphan the continuation lines just created.
    // The generation was already advanced, so earlier results cannot apply either.
    // Keep pending edit ranges for the next text edit or explicit formatting.
    if (changes.every((change) => change.rangeLength === 0 && /^[ \t]+$/.test(change.text))) {
      state.needsReflow = false;
      return;
    }
    if (newline) {
      state.enterChange = null;
      const eolLength = newline.text.startsWith("\r\n") ? 2 : 1;
      const boundary = moveOffset(newline.rangeOffset, changes, false) + eolLength;
      state.breaks.push(boundary);
      this.schedule(editor, { inspect: true, target: document.positionAt(Math.max(0, boundary - eolLength)) });
    } else {
      // Track every edit, including a zero-length point after deletion. The
      // document event can precede its selection event, so the current cursor
      // may still point at a different paragraph or even beyond the new EOF.
      state.needsReflow = true;
      for (const change of changes) {
        const start = moveOffset(change.rangeOffset, changes, false);
        state.affected.push({ start, end: start + change.text.length });
      }
      const merged = [];
      for (const range of state.affected.sort((a, b) => a.start - b.start)) {
        const previous = merged.at(-1);
        if (previous && range.start <= previous.end) previous.end = Math.max(previous.end, range.end);
        else merged.push(range);
      }
      state.affected = merged;
      this.schedule(editor, {});
    }
  }

  selected(event) {
    const state = this.states.get(event.textEditor.document);
    if (!state || state.applying) return;
    const editor = event.textEditor;
    if (state.needsReflow) {
      if (editor.selections.length === 1 && editor.selection.isEmpty) this.schedule(editor, {});
      return;
    }
    if (!state.scope) return;
    const offset = editor.document.offsetAt(editor.selection.active);
    if (editor.selections.length !== 1 || offset < state.scope.start || offset > state.scope.end) this.leave(editor);
  }

  leave(editor) {
    const state = this.states.get(editor.document);
    if (!state) return;
    const scope = state.scope;
    const protectedParagraph = state.breaks.length > 0;
    const affected = state.affected;
    this.reset(editor.document);
    state.affected = affected;
    if (affected.length) {
      state.needsReflow = true;
      this.schedule(editor, { flush: true });
      return;
    }
    if (scope && protectedParagraph && this.enabled(editor.document) && editor.selections.length === 1 && editor.selection.isEmpty) {
      const document = editor.document;
      const caret = document.offsetAt(editor.selection.active);
      const line = document.positionAt(scope.start).line;
      const target = caret >= scope.start && caret <= scope.end
        ? editor.selection.active : document.lineAt(line).range.end;
      this.schedule(editor, { flush: true, target });
    }
  }

  schedule(editor, options) {
    const state = this.state(editor.document);
    this.cancel(state);
    const generation = state.generation;
    // Preserve the next-turn handoff so the editor finishes its text and
    // cursor update before we take a snapshot. This is not a typing debounce.
    state.scheduledReflow = setTimeout(() => {
      state.scheduledReflow = null;
      this.reflow(editor, options, generation).catch((error) => this.reportError(error));
    }, 0);
  }

  async reflow(editor, options, generation) {
    const document = editor.document;
    const state = this.state(document);
    if (document.isClosed || state.generation !== generation || !this.enabled(document)) return;
    if (state.applying) {
      state.afterApply = { editor, options, generation };
      return;
    }
    if (editor.selections.length !== 1 || !editor.selection.isEmpty) return;
    if (!options.flush && vscode.window.activeTextEditor !== editor) return;
    const language = this.loadConfig()[document.languageId];
    if (!language) return;
    const version = document.version;
    const selections = editor.selections;
    const target = options.target || editor.selection.active;
    const source = document.getText();
    let protectedLines = state.breaks.map((at) => document.positionAt(at).line);
    const request = (cursor) => this.run(document, {
      source, language: document.languageId,
      cursor: { line: cursor.line, character: cursor.character },
      protected: protectedLines,
      width: language.width,
      tabWidth: Number(editor.options.tabSize) || language.tabWidth,
      minColWidth: language.minColWidth,
      tableGap: language.tableGap ?? 2,
    });
    const current = () => !document.isClosed && document.version === version && state.generation === generation;
    const result = await request(target);
    if (!current()) return;
    if (!options.flush) {
      if (result) {
        const start = document.offsetAt(new vscode.Position(result.first, 0));
        const end = document.offsetAt(document.lineAt(result.last).range.end);
        state.scope = { start, end };
        state.breaks = state.breaks.filter((at) => at >= start && at <= end);
        const caret = document.offsetAt(editor.selection.active);
        if (vscode.window.activeTextEditor !== editor || caret < start || caret > end) {
          this.leave(editor);
          return;
        }
      } else {
        state.breaks = [];
        state.scope = null;
      }
    }
    protectedLines = state.breaks.map((at) => document.positionAt(at).line);
    if (options.inspect && !state.affected.length) return;
    const edits = [];
    const inspected = [];
    const remember = (paragraph, line) => {
      let first = paragraph?.edit?.first ?? paragraph?.first ?? line;
      let last = paragraph?.edit?.last ?? paragraph?.last ?? line;
      for (const boundary of protectedLines) {
        if (boundary <= line) first = Math.max(first, boundary);
        else last = Math.min(last, boundary - 1);
      }
      inspected.push({ first, last });
    };
    if (!options.inspect || !result?.edit) remember(result, target.line);
    const ranges = state.affected.map((range) => ({
      first: document.positionAt(range.start).line, last: document.positionAt(range.end).line,
    }));
    if (!options.inspect && result?.edit) {
      // A selection notification can be a real cursor move. Retry the edited
      // ranges without formatting an unrelated paragraph at the new cursor.
      const affected = !ranges.length || options.target || ranges.some((range) =>
        range.first <= result.edit.last && range.last >= result.edit.first);
      if (affected) edits.push(result.edit);
    }
    // Query whole logical paragraphs against one immutable snapshot, then
    // apply all of their spacing changes in a single atomic editor edit.
    for (const range of ranges) {
      for (let line = range.first; line <= range.last;) {
        const covered = inspected.find((range) => range.first <= line && range.last >= line);
        if (covered) { line = covered.last + 1; continue; }
        const paragraph = await request(document.lineAt(line).range.end);
        if (!current()) return;
        remember(paragraph, line);
        if (paragraph?.edit) edits.push(paragraph.edit);
        let last = paragraph?.edit?.last ?? paragraph?.last ?? line;
        for (const boundary of protectedLines) {
          if (boundary > line) last = Math.min(last, boundary - 1);
        }
        line = Math.max(line, last) + 1;
      }
    }
    // Do not apply a result after the user has moved the cursor.
    if (editor.selections.length !== selections.length || editor.selections.some((selection, i) => !selection.isEqual(selections[i]))) return;
    const changes = edits.flatMap((edit) => {
      const start = document.offsetAt(new vscode.Position(edit.first, 0));
      const end = document.offsetAt(document.lineAt(edit.last).range.end);
      return spacingChanges(source.slice(start, end), edit.text, start);
    });
    if (!changes.length) {
      state.affected = [];
      state.needsReflow = false;
      return;
    }
    state.applying = true;
    state.expectedChanges = changes;
    try {
      // No selection assignment after this await: a newer keystroke may
      // already have reached VS Code even if we have not received its event.
      const applied = await editor.edit((builder) => {
        for (const change of changes) {
          builder.replace(new vscode.Range(
            document.positionAt(change.rangeOffset),
            document.positionAt(change.rangeOffset + change.rangeLength),
          ), change.text);
        }
      }, { undoStopBefore: Boolean(options.flush), undoStopAfter: Boolean(options.flush) });
      if (applied && state.generation === generation) {
        state.affected = [];
        state.needsReflow = false;
      }
    } finally {
      state.applying = false;
      state.expectedChanges = null;
      const afterApply = state.afterApply;
      state.afterApply = null;
      if (afterApply && afterApply.generation === state.generation && !document.isClosed) {
        this.schedule(afterApply.editor, afterApply.options);
      }
    }
  }

  close(document) {
    this.reset(document);
    this.states.delete(document);
  }

  dispose() {
    for (const state of this.states.values()) this.cancel(state);
    this.states.clear();
  }
}

module.exports = { LiveReflow, moveOffset, spacingChanges };

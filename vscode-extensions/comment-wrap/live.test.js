const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test, after } = require("node:test");
const vm = require("node:vm");

const temp = fs.mkdtempSync(path.join(os.tmpdir(), "comment-live-test-"));
const binary = path.join(temp, "live-comment-wrap");
execFileSync("go", ["build", "-o", binary, "./cmd/live-comment-wrap"], {
  cwd: path.resolve(__dirname, "../../comment-wrap"),
});
after(() => fs.rmSync(temp, { recursive: true, force: true }));

class Position {
  constructor(line, character) { Object.assign(this, { line, character }); }
  isEqual(other) { return this.line === other.line && this.character === other.character; }
}
class Range {
  constructor(a, b, c, d) {
    this.start = a instanceof Position ? a : new Position(a, b);
    this.end = b instanceof Position ? b : new Position(c, d);
  }
}
class Selection {
  constructor(anchor, active, line, character) {
    if (typeof anchor === "number") {
      const start = new Position(anchor, active);
      active = new Position(line, character);
      anchor = start;
    }
    Object.assign(this, { anchor, active });
  }
  get isEmpty() { return this.anchor.isEqual(this.active); }
  isEqual(other) { return this.anchor.isEqual(other.anchor) && this.active.isEqual(other.active); }
}
class Document {
  constructor(text, languageId) { Object.assign(this, { text, languageId, version: 1, isClosed: false }); }
  getText() { return this.text; }
  get lineCount() { return this.lines.length; }
  get eol() { return this.text.includes("\r\n") ? 2 : 1; }
  get lines() { return this.text.split(/\r?\n/); }
  lineAt(line) {
    const text = this.lines[line];
    assert.notEqual(text, undefined, `line ${line} outside ${this.text}`);
    return { text, range: new Range(new Position(line, 0), new Position(line, text.length)) };
  }
  offsetAt({ line, character }) {
    const eolLength = this.text.includes("\r\n") ? 2 : 1;
    return this.lines.slice(0, line).reduce((n, text) => n + text.length + eolLength, character);
  }
  positionAt(offset) {
    const lines = this.text.slice(0, offset).split(/\r?\n/);
    return new Position(lines.length - 1, lines.at(-1).length);
  }
}

function harness(marked, language = "go", width = 24, tableGap = 2) {
  const document = new Document(marked.replace("|", ""), language);
  const at = document.positionAt(marked.indexOf("|"));
  const editor = {
    document, options: { tabSize: 4 }, selections: [new Selection(at, at)], edits: [], selectionWrites: 0,
    get selection() { return this.selections[0]; },
    set selection(value) { this.selectionWrites++; this.selections = [value]; },
    async edit(build, options) {
      const edits = [];
      build({ replace: (range, text) => edits.push({ range, text, rangeOffset: document.offsetAt(range.start), rangeLength: document.offsetAt(range.end) - document.offsetAt(range.start) }) });
      if (options) this.edits.push(options);
      const offsets = this.selections.map((selection) => ({ anchor: document.offsetAt(selection.anchor), active: document.offsetAt(selection.active) }));
      change(edits);
      // Model the UI tracking selections as part of the same edit, before
      // any later keystroke or extension-host selection command can run.
      const moveOffset = context.module.exports.moveOffset;
      this.selections = offsets.map((selection) => new Selection(
        document.positionAt(moveOffset(selection.anchor, edits)), document.positionAt(moveOffset(selection.active, edits)),
      ));
      return true;
    },
  };
  let enabled = true;
  const vscode = {
    Position, Range, Selection, window: { activeTextEditor: editor },
    workspace: { getConfiguration: () => ({ get: () => enabled }) },
  };
  const timers = new Map();
  const delays = [];
  let nextTimer = 0;
  const context = {
    module: { exports: {} }, require: () => vscode,
    setTimeout: (callback, delay) => { delays.push(delay); timers.set(++nextTimer, callback); return nextTimer; },
    clearTimeout: (id) => timers.delete(id),
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "live.js"), "utf8"), context);
  const calls = [];
  let delayed = null;
  const controller = new context.module.exports.LiveReflow(async (_document, request) => {
    calls.push(request);
    const result = JSON.parse(execFileSync(binary, [], { input: JSON.stringify(request), encoding: "utf8" }));
    if (delayed) await delayed;
    return result;
  }, () => ({ [language]: { width, tabWidth: 4, minColWidth: 8, tableGap } }), (error) => { throw error; });

  function change(changes, reason) {
    for (const edit of [...changes].sort((a, b) => b.rangeOffset - a.rangeOffset)) {
      document.text = document.text.slice(0, edit.rangeOffset) + edit.text + document.text.slice(edit.rangeOffset + edit.rangeLength);
    }
    document.version++;
    controller.changed({ document, contentChanges: [...changes].reverse(), reason });
  }
  function type(text, length = 0) {
    const start = editor.selection.active;
    const offset = document.offsetAt(start);
    change([{ range: new Range(start, document.positionAt(offset + length)), rangeOffset: offset, rangeLength: length, text }]);
    const end = document.positionAt(offset + text.length);
    editor.selection = new Selection(end, end);
    controller.selected({ textEditor: editor });
  }
  async function enter() {
    let command;
    const continuationContext = {
      module: { exports: {} },
      require: () => ({
        ...vscode, EndOfLine: { CRLF: 2 },
        workspace: { getConfiguration: () => ({ get: (_key, fallback) => fallback }) },
        extensions: { getExtension: () => ({ isActive: true, exports: {
          protectEnter: (document, change) => controller.protectEnter(document, change),
        } }) },
        commands: { registerCommand: (name, callback) => {
          if (name === "lineCommentContinue.enter") command = callback;
          return { dispose() {} };
        } },
      }),
    };
    vm.runInNewContext(fs.readFileSync(path.resolve(__dirname, "../line-comment-continue/extension.js"), "utf8"), continuationContext);
    continuationContext.module.exports.activate({ subscriptions: [] });
    await command();
    controller.selected({ textEditor: editor });
  }

  function select(offset) {
    const at = document.positionAt(offset);
    editor.selection = new Selection(at, at);
    controller.selected({ textEditor: editor });
  }
  async function drain() {
    // Scheduled callbacks start asynchronous helper requests.
    for (let n = 0; n < 5 && timers.size; n++) {
      const callbacks = [...timers.values()]; timers.clear();
      callbacks.forEach((callback) => callback());
      await new Promise((resolve) => setImmediate(resolve));
    }
  }
  function output() {
    const at = document.offsetAt(editor.selection.active);
    return document.text.slice(0, at) + "|" + document.text.slice(at);
  }
  return { controller, document, editor, calls, delays, change, type, enter, select, drain, output, vscode,
    disable: () => { enabled = false; },
    delay: () => { let resolve; delayed = new Promise((r) => { resolve = r; }); return resolve; },
  };
}

test("typing overflow and deleting underflow preserve the caret and group undo", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  h.type("a"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma\n// delta|");
  assert.equal(h.editor.edits[0].undoStopBefore, false);
  assert.equal(h.editor.edits[0].undoStopAfter, false);
  h.select(3); h.type("", 6); await h.drain();
  assert.equal(h.output(), "// |beta gamma delta");
});

test("Enter protection survives repeated lower-segment reflow until leaving", async () => {
  const h = harness("// alpha |beta gamma delta epsilon\ncode()", "go", 24);
  await h.enter(); await h.drain();
  assert.equal(h.output(), "// alpha \n// |beta gamma delta epsilon\ncode()");
  h.type("new "); await h.drain();
  assert.equal(h.output(), "// alpha \n// new |beta gamma delta\n// epsilon\ncode()");
  assert.equal(h.controller.state(h.document).breaks.length, 1);
  h.type("more "); await h.drain();
  assert.ok(h.document.text.startsWith("// alpha \n// new more "));
  assert.equal(h.controller.state(h.document).breaks.length, 1);
  h.select(h.document.text.length); await h.drain();
  assert.equal(h.output(), "// alpha new more beta\n// gamma delta epsilon\ncode()|");
  assert.equal(h.controller.state(h.document).breaks.length, 0);
});

test("Enter into an empty comment keeps protection while typing the first word", async () => {
  const h = harness("// alpha|\ncode()", "go", 30);
  await h.enter(); await h.drain();
  h.type("b"); await h.drain();
  assert.equal(h.output(), "// alpha\n// b|\ncode()");
  h.type("eta "); await h.drain();
  assert.equal(h.output(), "// alpha\n// beta |\ncode()");
  h.select(h.document.text.length); await h.drain();
  assert.equal(h.output(), "// alpha beta\ncode()|");
});

test("moving within a protected paragraph does not release its boundary", async () => {
  const h = harness("// alpha |beta gamma\ncode()", "go", 30);
  await h.enter(); await h.drain();
  h.select(5); h.type("x"); await h.drain();
  assert.ok(h.document.text.startsWith("// alxpha\n"));
  assert.equal(h.controller.state(h.document).breaks.length, 1);
});

test("explicit formatting resets protection and cancels pending live edits", async () => {
  const h = harness("// alpha |beta gamma", "go", 30);
  await h.enter(); await h.drain();
  h.type("new ");
  h.controller.reset(h.document); await h.drain();
  assert.equal(h.controller.state(h.document).breaks.length, 0);
  assert.equal(h.editor.edits.length, 0);
});

test("undo and redo never trigger another reflow", async () => {
  for (const reason of [1, 2]) {
    const h = harness("// alpha beta gamma delt|", "go", 24);
    h.type("a");
    const at = h.editor.selection.active;
    h.change([{ range: new Range(at, at), rangeOffset: h.document.offsetAt(at), rangeLength: 0, text: "x" }], reason);
    await h.drain();
    assert.equal(h.calls.length, 0);
  }
});

test("typing while a result is in flight discards that result", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  const release = h.delay();
  h.type("a"); await h.drain();
  h.type("x"); release();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(h.editor.edits.length, 0);
  await h.drain();
  assert.equal(h.output(), "// alpha beta gamma\n// deltax|");
});

test("moving the caret during an asynchronous result never restores its old position", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  const release = h.delay();
  h.type("a"); await h.drain();
  h.select(5); release();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(h.editor.edits.length, 0);
  assert.equal(h.document.offsetAt(h.editor.selection.active), 5);
});

test("disabled reflow and multiple cursors leave text alone", async () => {
  for (const multi of [false, true]) {
    const h = harness("// alpha beta gamma delt|", "go", 24);
    if (multi) h.editor.selections.push(h.editor.selection); else h.disable();
    h.type("a"); await h.drain();
    assert.equal(h.calls.length, 0);
  }
});

test("single-line paste still reflows the active comment", async () => {
  const h = harness("// |", "go", 20);
  h.type("alpha beta gamma delta epsilon"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma\n// delta epsilon|");
  assert.equal(h.editor.edits.length, 1);
});

test("switching editors releases protection and preserves the old editor selection", async () => {
  const h = harness("// alpha |beta\ncode()", "go", 30);
  await h.enter(); await h.drain();
  h.vscode.window.activeTextEditor = undefined;
  h.controller.leave(h.editor); await h.drain();
  assert.equal(h.output(), "// alpha |beta\ncode()");
});

test("CRLF documents keep their line endings", async () => {
  const h = harness("// alpha beta gamma delt|\r\ncode()", "go", 24);
  h.type("a"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma\r\n// delta|\r\ncode()");
});

for (const [name, input, expectedPrefix, typed = "new "] of [
  ["standard", "// - alpha|\n//   beta gamma", "// - alpha\n// - new beta gamma"],
  ["numeric renumbering", "// 9. alpha|\n//    beta gamma\n// 10. later", "// 9. alpha\n// 10. new beta gamma\n// 11. later"],
  ["word", "// Args:\n//   name: alpha|\n//         beta gamma", "// Args:\n//   name: alpha\n//   new: \n//         beta gamma", "new: "],
  ["whitespace", "// Args:\n//   alpha beta|\n//     gamma delta", "// Args:\n//   alpha beta\n//   new item gamma delta", "new item "],
  ["colon", "// Args:|", "// Args:\n//   new "],
]) {
  test(`current continuation tool cooperates with live reflow: ${name}`, async () => {
    const h = harness(input, "go", 60);
    await h.enter(); await h.drain();
    const afterEnter = h.document.text;
    assert.equal(h.editor.edits.length, 0, "Enter must not trigger live adjustment");
    h.type(typed); await h.drain();
    assert.equal(h.document.text, expectedPrefix);
    assert.ok(afterEnter.includes("\n//"));
  });
}

test("undo arriving before an edit promise resolves cannot restore a stale caret", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  const apply = h.editor.edit.bind(h.editor);
  h.editor.edit = async (...args) => {
    await apply(...args);
    const end = h.document.positionAt(h.document.text.length);
    h.change([{ range: new Range(new Position(0, 0), end), rangeOffset: 0, rangeLength: h.document.text.length, text: "// restored" }], 1);
    const at = new Position(0, 5);
    h.editor.selection = new Selection(at, at);
    return true;
  };
  h.type("a"); await h.drain();
  assert.equal(h.output(), "// re|stored");
  assert.equal(h.controller.state(h.document).scope, null);
});

test("a blank comment introduced by a second Enter stays a real paragraph boundary", async () => {
  const h = harness("// alpha|\ncode()", "go", 30);
  await h.enter(); await h.drain();
  await h.enter(); await h.drain();
  h.type("beta"); await h.drain();
  h.select(h.document.text.length); await h.drain();
  assert.equal(h.document.text, "// alpha\n// \n// beta\ncode()");
});

test("successive keystrokes reflow on the next turn without a typing pause", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  h.type("a"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma\n// delta|");
  h.type("x"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma\n// deltax|");
  assert.ok(h.delays.length >= 2);
  assert.ok(h.delays.every((delay) => delay === 0), `unexpected typing delay: ${h.delays}`);
});

const { LiveFormatter } = require("./live-formatter");
function workerRequest(source) {
  return { source, language: "go", cursor: { line: 0, character: source.length }, protected: [], width: 24, tabWidth: 4, minColWidth: 8 };
}

test("a persistent helper keeps only the newest pending state per document", async (t) => {
  const worker = new LiveFormatter(binary);
  t.after(() => worker.dispose());
  const document = {};
  const first = worker.run(document, workerRequest("// alpha beta gamma delta"));
  const child = worker.child;
  const skipped = worker.run(document, workerRequest("// alpha beta gamma deltax"));
  const latest = worker.run(document, workerRequest("// alpha beta gamma deltaxx"));
  assert.equal(worker.pending.size, 1);
  const [a, b, c] = await Promise.all([first, skipped, latest]);
  assert.equal(a.edit.text, "// alpha beta gamma\n// delta");
  assert.equal(b, null);
  assert.equal(c.edit.text, "// alpha beta gamma\n// deltaxx");
  assert.equal(worker.child, child);
  assert.equal(worker.pending.size, 0);
  const again = await worker.run(document, workerRequest("// short"));
  assert.equal(again.edit, undefined);
  assert.equal(worker.child, child, "subsequent typing must reuse the process");
});

test("pending work for another document survives rapid updates", async (t) => {
  const worker = new LiveFormatter(binary);
  t.after(() => worker.dispose());
  const a = {}, b = {};
  const first = worker.run(a, workerRequest("// first"));
  const other = worker.run(b, workerRequest("// second"));
  const updates = [];
  for (let n = 0; n < 30; n++) updates.push(worker.run(a, workerRequest(`// alpha beta gamma delta${n}`)));
  assert.equal(worker.pending.size, 2);
  const results = await Promise.all([first, other, ...updates]);
  assert.equal(results[1].first, 0);
  assert.ok(results.slice(2, -1).every((result) => result === null));
  assert.equal(results.at(-1).edit.text, "// alpha beta gamma\n// delta29");
});

test("a crashed helper fails outstanding work and restarts on the next edit", async (t) => {
  const worker = new LiveFormatter(binary);
  t.after(() => worker.dispose());
  const a = {}, b = {};
  const first = worker.run(a, workerRequest("// first"));
  const queued = worker.run(b, workerRequest("// second"));
  const child = worker.child;
  const failures = Promise.allSettled([first, queued]);
  child.kill();
  assert.ok((await failures).every((result) => result.status === "rejected"));
  assert.equal(worker.child, null);
  const result = await worker.run(a, workerRequest("// alpha beta gamma delta"));
  assert.equal(result.edit.text, "// alpha beta gamma\n// delta");
  assert.notEqual(worker.child, child);
});

test("disposal settles pending requests and stops the helper", async () => {
  const worker = new LiveFormatter(binary);
  const first = worker.run({}, workerRequest("// first"));
  const queued = worker.run({}, workerRequest("// second"));
  const child = worker.child;
  worker.dispose();
  assert.deepEqual(await Promise.all([first, queued]), [null, null]);
  assert.equal(worker.child, null);
  assert.equal(child.killed, true);
  assert.equal(await worker.run({}, workerRequest("// third")), null);
});

test("reported fast-typing sequence keeps every letter before the caret", async () => {
  const input = "# wdfkj sdkf dsk fhdsj fhdjskf hkjsd fdshfjksd hfkdjsfh kjsd dsf hdskjf hdskjfhdskj sdf jksh fkjsdhfjkds jkfdsjkdhh";
  const h = harness("|", "shellscript", 100);
  for (const character of input) {
    h.type(character);
    const writes = h.editor.selectionWrites;
    await h.drain();
    assert.equal(h.editor.selectionWrites, writes, "reflow must not send a separate cursor update");
    assert.equal(h.document.offsetAt(h.editor.selection.active), h.document.text.length);
  }
  assert.equal(h.output(), "# wdfkj sdkf dsk fhdsj fhdjskf hkjsd fdshfjksd hfkdjsfh kjsd dsf hdskjf hdskjfhdskj sdf jksh\n# fkjsdhfjkds jkfdsjkdhh|");
});

test("a key accepted by the UI before its document event cannot be overtaken by a cursor update", async () => {
  const h = harness("# alpha beta gamma delt|", "shellscript", 22);
  const apply = h.editor.edit.bind(h.editor);
  let unreported;
  h.editor.edit = async (...args) => {
    await apply(...args);
    // The UI has accepted another key, but its document-change notification
    // is still in transit. The version/generation guards cannot see it yet.
    const start = h.editor.selection.active;
    const offset = h.document.offsetAt(start);
    unreported = { range: new Range(start, start), rangeOffset: offset, rangeLength: 0, text: "h" };
    h.document.text = h.document.text.slice(0, offset) + "h" + h.document.text.slice(offset);
    const at = h.document.positionAt(offset + 1);
    h.editor.selections = [new Selection(at, at)];
    return true;
  };
  h.type("a");
  const writes = h.editor.selectionWrites;
  await h.drain();
  assert.equal(h.output(), "# alpha beta gamma\n# deltah|");
  assert.equal(h.editor.selectionWrites, writes);
  h.document.version++;
  h.controller.changed({ document: h.document, contentChanges: [unreported] });
  await h.drain();
  assert.equal(h.output(), "# alpha beta gamma\n# deltah|");
});

test("typing during an edit waits for that edit and then processes the newest state", async () => {
  const h = harness("# alpha beta gamma delt|", "shellscript", 22);
  const apply = h.editor.edit.bind(h.editor);
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  h.editor.edit = async (...args) => { await apply(...args); await gate; return true; };
  h.type("a"); await h.drain();
  assert.equal(h.output(), "# alpha beta gamma\n# delta|");
  const calls = h.calls.length;
  h.type("x"); await h.drain();
  h.type("y"); await h.drain();
  assert.equal(h.calls.length, calls, "do not start overlapping reflow edits");
  release(); await new Promise((resolve) => setImmediate(resolve));
  await h.drain();
  assert.equal(h.calls.at(-1).source, "# alpha beta gamma\n# deltaxy");
  assert.equal(h.output(), "# alpha beta gamma\n# deltaxy|");
});

for (const [name, input, expected, width = 22] of [
  ["within a word", "# alpha beta gamma del|ta epsilon", "# alpha beta gamma\n# del|ta epsilon"],
  ["typing gap at wrap", "# alpha beta gamma |delta", "# alpha beta gamma\n# |delta"],
  ["trailing typing gap", "# alpha beta gamma delta |", "# alpha beta gamma\n# delta |"],
  ["underfull line end", "# alpha|\n# beta gamma", "# alpha| beta gamma", 30],
  ["Unicode", "# 🙂 alpha beta gam|ma delta", "# 🙂 alpha beta\n# gam|ma delta", 19],
  ["rewrap before and after the caret", "# alpha beta\n# gam|ma delta epsilon zeta", "# alpha beta gamma\n# delta epsilon zeta".replace("gamma", "gam|ma"), 22],
]) {
  test(`native cursor tracking: ${name}`, async () => {
    const h = harness(input, "shellscript", width);
    h.controller.schedule(h.editor, {});
    await h.drain();
    assert.equal(h.output(), expected);
    assert.equal(h.editor.selectionWrites, 0);
    assert.equal(h.controller.state(h.document).breaks.length, 0, "reflow edits must not create Enter protection");
  });
}

test("deleting a comment prefix then backspacing the newline immediately reflows the joined bullet", async () => {
  const intro = '# <new-order> contains comma-separated fields, where each field can be:';
  const first = '#   an integer i, to mean the original field i (0-based).';
  const prefix = '#   a range i-j, ';
  const rest = 'as shorthand for i,i+1,etc,j-1,j (if i < j) or i,i-1,etc,j+1,j (if i > j) or i (if i == j).';
  const last = '#   -i, to mean "ignore field i" for the `...` syntax below.';
  const h = harness(`${intro}\n${first}\n|${prefix}${rest}\n${last}`, "shellscript", 100);
  h.type("", prefix.length); await h.drain();
  assert.equal(h.output(), `${intro}\n${first}\n|${rest}\n${last}`);
  const at = h.document.offsetAt(h.editor.selection.active);
  h.select(at - 1);
  h.type("", 1); await h.drain();
  assert.equal(h.output(), `${intro}\n#   an integer i, to mean the original field i (0-based).|as shorthand for i,i+1,etc,j-1,j (if i < j)\n#     or i,i-1,etc,j+1,j (if i > j) or i (if i == j).\n${last}`);
  assert.equal(h.controller.state(h.document).breaks.length, 0);
});

for (const eol of ["\n", "\r\n"]) {
  for (const direction of ["backspace", "delete"]) {
    test(`${direction} across ${JSON.stringify(eol)} immediately wraps the merged comment`, async () => {
      const marker = direction === "delete" ? `|${eol}` : `${eol}|`;
      const h = harness(`// alpha beta gamma delta${marker} epsilon${eol}code()`, "go", 24);
      if (direction === "backspace") {
        h.select(h.document.offsetAt(h.editor.selection.active) - eol.length);
      }
      h.type("", eol.length); await h.drain();
      assert.equal(h.output(), `// alpha beta gamma${eol}// delta| epsilon${eol}code()`);
      assert.equal(h.controller.state(h.document).breaks.length, 0);
    });
  }
}

for (const [name, pasted, language] of [
  ["paragraphs", "// alpha beta gamma delta epsilon\n//\n// one two three four five six seven", "go"],
  ["one newline", "\n// beta", "go"],
  ["just a newline", "\n", "go"],
  ["comments ending on code", "// alpha beta gamma delta epsilon\ncode()", "go"],
  ["comments ending on a blank line", "// alpha beta gamma delta epsilon\n", "go"],
  ["bullets", "# - alpha beta gamma delta epsilon\n# - one two three four five six seven", "shellscript"],
  ["tables", "// a  alpha beta gamma delta\n// bb  epsilon zeta\n", "go"],
  ["CRLF", "// alpha beta gamma delta epsilon\r\n//\r\n// one two three four five six seven", "go"],
]) {
  test(`multiline paste preserves ${name} without requesting reflow`, async () => {
    const h = harness("|", language, 24);
    h.type(pasted); await h.drain();
    assert.equal(h.output(), pasted + "|");
    assert.equal(h.calls.length, 0);
    assert.equal(h.editor.edits.length, 0);
    assert.equal(h.controller.state(h.document).affected.length, 0);
    assert.equal(h.controller.state(h.document).needsReflow, false);
    h.select(0); await h.drain();
    h.controller.leave(h.editor); await h.drain();
    assert.equal(h.document.text, pasted);
    assert.equal(h.calls.length, 0);
  });
}

test("a 5000-line code paste stays exact and makes no helper requests", async () => {
  const pasted = Array.from({ length: 5000 }, (_, i) => i % 10 === 0
    ? `// comment ${i} with enough words to exceed the wrapping width`
    : `const value${i} = ${i};`).join("\n");
  const h = harness("|", "javascript", 24);
  h.type(pasted); await h.drain();
  assert.equal(h.document.text, pasted);
  assert.equal(h.calls.length, 0);
  assert.equal(h.editor.edits.length, 0);
  assert.equal(h.controller.state(h.document).affected.length, 0);
});

test("typing after a multiline paste only reflows the edited paragraph", async () => {
  const before = "// alpha beta gamma delta epsilon\n//\n";
  const h = harness("|", "go", 24);
  h.type(before + "// one two three four five six"); await h.drain();
  h.type(" seven"); await h.drain();
  assert.equal(h.output(), before + "// one two three four\n// five six seven|");
  assert.equal(h.controller.state(h.document).affected.length, 0);
});

test("a multiline paste cancels queued formatting of an earlier edit", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  h.type("a");
  assert.ok(h.controller.state(h.document).affected.length);
  h.type("\n// pasted paragraph deliberately left overfull"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma delta\n// pasted paragraph deliberately left overfull|");
  assert.equal(h.calls.length, 0);
  assert.equal(h.controller.state(h.document).affected.length, 0);
});

test("a multiline paste invalidates in-flight formatting and clears its pending ranges", async () => {
  const h = harness("// alpha beta gamma delt|", "go", 24);
  const release = h.delay();
  h.type("a"); await h.drain();
  h.type("\n//\n// one two three four five six");
  release(); await new Promise((resolve) => setImmediate(resolve));
  await h.drain();
  assert.equal(h.output(), "// alpha beta gamma delta\n//\n// one two three four five six|");
  assert.equal(h.editor.edits.length, 0);
  assert.equal(h.controller.state(h.document).affected.length, 0);
  h.type(" seven"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma delta\n//\n// one two three four\n// five six seven|");
});

test("pasting into an Enter-protected paragraph keeps its boundary without scheduling a later flush", async () => {
  const h = harness("// alpha|", "go", 24);
  await h.enter(); await h.drain();
  const calls = h.calls.length;
  const pasted = "beta gamma delta epsilon\n// zeta eta theta iota";
  h.type(pasted); await h.drain();
  assert.equal(h.output(), "// alpha\n// " + pasted + "|");
  assert.equal(h.controller.state(h.document).breaks.length, 1);
  h.select(0); await h.drain();
  h.controller.leave(h.editor); await h.drain();
  assert.equal(h.calls.length, calls);
  assert.equal(h.document.text, "// alpha\n// " + pasted);
});

test("spaces after the bullet in the reported example never wrap or rearrange its text", async () => {
  const intro = '# <new-order> contains comma-separated fields, where each field can be:';
  const first = '#   * an integer i, to mean the original field i (0-based).';
  const content = 'a range i-j, as shorthand for i,i+1,etc,j-1,j (if i < j) or i,i-1,etc,j+1,j (if i > j)';
  const h = harness(`${intro}\n${first}\n#   * |${content}`, "shellscript", 100);
  for (let n = 1; n <= 60; n++) {
    h.type(" "); await h.drain();
    assert.equal(h.output(), `${intro}\n${first}\n#   * ${" ".repeat(n)}|${content}`, `after ${n} inserted spaces`);
  }
  assert.equal(h.editor.edits.length, 0);
});

for (const [name, input] of [
  ["comment indentation", "# |alpha beta gamma delta epsilon"],
  ["before the comment marker", "|# alpha beta gamma delta epsilon"],
  ["middle of prose", "# alpha |beta gamma delta epsilon"],
  ["a standard bullet", "# - |alpha beta gamma delta epsilon"],
  ["a numeric bullet", "# 12. |alpha beta gamma delta epsilon"],
  ["a word bullet", "# Args:\n#   name: |alpha beta gamma delta epsilon"],
  ["an existing bullet continuation", "# - alpha beta\n#   |gamma delta epsilon"],
]) {
  test(`horizontal whitespace insertion preserves ${name}`, async () => {
    const h = harness(input, "shellscript", 24);
    let inserted = "";
    for (const whitespace of [" ", " ", "\t", "    "]) {
      inserted += whitespace;
      h.type(whitespace); await h.drain();
      assert.equal(h.output(), input.replace("|", inserted + "|"));
    }
    assert.equal(h.editor.edits.length, 0);
  });
}

test("text insertion resumes reflow after editing a whitespace gap", async () => {
  const h = harness("# - |alpha beta gamma delta epsilon", "shellscript", 24);
  h.type("  "); await h.drain();
  assert.equal(h.editor.edits.length, 0);
  assert.equal(h.output(), "# -   |alpha beta gamma delta epsilon");
  h.type("new "); await h.drain();
  assert.equal(h.output(), "# -   new |alpha beta\n#     gamma delta\n#     epsilon");
  assert.equal(h.editor.edits.length, 1);
});

test("a space invalidates an in-flight result before it can wrap the comment", async () => {
  const h = harness("# - |alpha beta gamma delta epsilon", "shellscript", 24);
  const release = h.delay();
  h.type("x"); await h.drain();
  h.type(" ");
  release(); await new Promise((resolve) => setImmediate(resolve));
  await h.drain();
  assert.equal(h.output(), "# - x |alpha beta gamma delta epsilon");
  assert.equal(h.editor.edits.length, 0);
});

test("spacing after a skipped paste does not defer its formatting to later typing", async () => {
  const h = harness("|", "go", 24);
  const pasted = "// alpha beta gamma delta epsilon\n//\n// one two three four five six";
  h.type(pasted); await h.drain();
  h.type(" "); await h.drain();
  assert.equal(h.output(), pasted + " |");
  assert.equal(h.calls.length, 0);
  assert.equal(h.editor.edits.length, 0);
  h.type("seven"); await h.drain();
  assert.equal(h.output(), "// alpha beta gamma delta epsilon\n//\n// one two three four\n// five six seven|");
  assert.equal(h.controller.state(h.document).affected.length, 0);
});

for (const laterSibling of [false, true]) {
  test(`selection deletion then Backspace reflows when cursor notifications arrive late (later sibling: ${laterSibling})`, async () => {
    const intro = '# <new-order> contains comma-separated fields, where each field can be:';
    const first = '#   * an integer i, to mean the original field i (0-based).';
    const prefix = '#   * ';
    const rest = 'a range i-j, as shorthand for i,i+1,etc,j-1,j (if i < j) or i,i-1,etc,j+1,j (if i > j) or i (if i == j).';
    const suffix = laterSibling ? '\n#   * next item' : '';
    const h = harness(`${intro}\n${first}\n${prefix}|${rest}${suffix}`, 'shellscript', 100);
    // Cmd+Backspace performs cursorHomeSelect then deleteLeft. A manual
    // selection followed by Backspace produces these same native events.
    const anchor = new Position(2, prefix.length), start = new Position(2, 0);
    h.editor.selection = new Selection(anchor, start);
    h.controller.selected({ textEditor: h.editor });
    h.change([{ range: new Range(start, anchor), rangeOffset: h.document.offsetAt(start), rangeLength: prefix.length, text: '' }]);
    await h.drain(); // The document is updated; the selection still is not.
    h.editor.selection = new Selection(start, start);
    h.controller.selected({ textEditor: h.editor });
    await h.drain();
    assert.equal(h.output(), `${intro}\n${first}\n|${rest}${suffix}`);
    const previousEnd = new Position(1, first.length);
    h.change([{ range: new Range(previousEnd, start), rangeOffset: h.document.offsetAt(previousEnd), rangeLength: 1, text: '' }]);
    await h.drain(); // The old cursor now names another line, or past EOF.
    h.editor.selection = new Selection(previousEnd, previousEnd);
    h.controller.selected({ textEditor: h.editor });
    await h.drain();
    assert.equal(h.output(), `${intro}\n#   * an integer i, to mean the original field i (0-based).|a range i-j, as shorthand for\n#     i,i+1,etc,j-1,j (if i < j) or i,i-1,etc,j+1,j (if i > j) or i (if i == j).${suffix}`);
  });
}

test('a deletion skipped while the old selection is nonempty retries when it collapses', async () => {
  const h = harness('// alpha |remove this\n// beta gamma delta epsilon', 'go', 24);
  const start = new Position(0, 9), end = new Position(0, 20);
  h.editor.selection = new Selection(end, start);
  h.change([{ range: new Range(start, end), rangeOffset: h.document.offsetAt(start), rangeLength: 11, text: '' }]);
  await h.drain();
  assert.equal(h.editor.edits.length, 0);
  h.editor.selection = new Selection(start, start);
  h.controller.selected({ textEditor: h.editor });
  await h.drain();
  assert.equal(h.output(), '// alpha |beta gamma\n// delta epsilon');
});

test('a cursor notification during helper execution retries a joined line without another keystroke', async () => {
  const h = harness('// alpha beta gamma delta\n| epsilon', 'go', 24);
  const release = h.delay();
  const start = new Position(0, 25), end = new Position(1, 0);
  h.change([{ range: new Range(start, end), rangeOffset: 25, rangeLength: 1, text: '' }]);
  await h.drain();
  h.editor.selection = new Selection(start, start);
  h.controller.selected({ textEditor: h.editor });
  release(); await new Promise((resolve) => setImmediate(resolve));
  await h.drain();
  assert.equal(h.output(), '// alpha beta gamma\n// delta| epsilon');
  assert.equal(h.controller.state(h.document).needsReflow, false);
});

test('a settled edit inspects its paragraph only once', async () => {
  const h = harness('// short|', 'go', 100);
  h.type('x'); await h.drain();
  assert.equal(h.calls.length, 1);
  assert.equal(h.controller.state(h.document).affected.length, 0);
  assert.equal(h.controller.state(h.document).needsReflow, false);
});

test('retrying after a cursor move formats the edited paragraph without touching the destination paragraph', async () => {
  const untouched = '// untouched paragraph deliberately remains overfull';
  const h = harness(`// alpha beta gamma delt|\n//\n${untouched}`, 'go', 24);
  const release = h.delay();
  h.type('a'); await h.drain();
  h.select(h.document.offsetAt(new Position(2, 3)));
  release(); await new Promise((resolve) => setImmediate(resolve));
  await h.drain();
  assert.equal(h.output(), '// alpha beta gamma\n// delta\n//\n// |untouched paragraph deliberately remains overfull');
  assert.equal(h.editor.selectionWrites, 2, 'only the two simulated user actions move the cursor explicitly');
});


test("deleting the widest table row collapses padding", async () => {
  const lastRow = "\n// a much longer option  removed";
  const h = harness("// a                     alpha\n// bb                    beta|" + lastRow, "go", 80);
  h.type("", lastRow.length); await h.drain();
  assert.equal(h.output(), "// a   alpha\n// bb  beta|");
});

test("live reflow uses the configured table gap", async () => {
  const h = harness("// a        alpha|\n// bb       beta", "go", 80, 4);
  h.type("x"); await h.drain();
  assert.equal(h.calls[0].tableGap, 4);
  assert.equal(h.output(), "// a     alphax|\n// bb    beta");
});


test("typing a first table row preserves separators until a second row exists", async () => {
  const h = harness("// a|", "go", 24);
  let firstRow = "// a";
  for (const text of ["  ", ..."alpha beta gamma delta"]) {
    h.type(text); await h.drain();
    firstRow += text;
    assert.equal(h.output(), firstRow + "|");
  }
  h.type("\n// bb  "); await h.drain();
  assert.equal(h.output(), firstRow + "\n// bb  |");
  h.type("gamma"); await h.drain();
  assert.equal(h.output(), "// a   alpha beta gamma\n//     delta\n// bb  gamma|");
});

test("typing a single table row after an intro preserves its separators", async () => {
  const h = harness("# Options:\n#   --all|", "shellscript", 24);
  let row = "# Options:\n#   --all";
  for (const text of ["  ", ..."alpha beta gamma delta"]) {
    h.type(text); await h.drain();
    row += text;
    assert.equal(h.output(), row + "|");
  }
});

test("deletion creating a double space leaves the single prose row editable", async () => {
  const h = harness("// alpha |x beta gamma delta", "go", 16);
  h.type("", 1); await h.drain();
  assert.equal(h.output(), "// alpha | beta gamma delta");
  h.select(h.document.text.indexOf("beta") + "beta".length);
  h.type("z"); await h.drain();
  assert.equal(h.output(), "// alpha  betaz| gamma delta");
});

test("deletion creating an extra table item does not restructure the row", async () => {
  const h = harness("// a  alpha beta\n// bb  gamma |x delta\n// c  epsilon zeta", "go", 16);
  h.type("", 1); await h.drain();
  assert.equal(h.output(), "// a  alpha beta\n// bb  gamma | delta\n// c  epsilon zeta");
});

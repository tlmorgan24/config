const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

class Position {
  constructor(line, character) { Object.assign(this, { line, character }); }
}
class Selection {
  constructor(anchor, active) {
    Object.assign(this, { anchor, active });
    this.isEmpty = anchor.line === active.line && anchor.character === active.character;
  }
}

function harness(lines, languageId = "python", columns = [lines[0].length], homeTarget) {
  const calls = [];
  const editor = {
    document: { languageId, lineAt: (line) => ({ text: lines[line] }) },
    selections: columns.map((column, line) => {
      const position = new Position(line, column);
      return new Selection(position, position);
    }),
    get selection() { return this.selections[0]; },
    revealRange() {},
  };
  const vscode = {
    Position, Selection, Range: class {},
    window: { activeTextEditor: editor },
    commands: {
      async executeCommand(command) {
        calls.push(command);
        editor.selections = editor.selections.map((selection) => {
          const { line, character } = selection.active;
          if (command === "deleteLeft") {
            const start = Math.min(selection.anchor.character, character);
            const end = Math.max(selection.anchor.character, character);
            lines[line] = lines[line].slice(0, start) + lines[line].slice(end);
            const position = new Position(line, start);
            return new Selection(position, position);
          }
          const first = lines[line].search(/\S/);
          const column = homeTarget ?? (character === first || first === -1 ? 0 : first);
          const position = new Position(line, column);
          return new Selection(command === "cursorHomeSelect" ? selection.anchor : position, position);
        });
      },
    },
  };
  const context = { module: { exports: {} }, require: () => vscode };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "extension.js"), "utf8"), context);
  return { editor, lines, calls, home: context.module.exports.commentHome };
}

for (const [language, marker] of Object.entries({
  go: "//", shellscript: "#", python: "#", javascript: "//", javascriptreact: "//",
  typescript: "//", typescriptreact: "//", json: "//", jsonc: "//",
})) {
  test(`${language}: movement stops at text, marker, then column zero`, async () => {
    const h = harness([`  ${marker}   hello`], language);
    for (const expected of [2 + marker.length + 3, 2, 0]) {
      await h.home();
      assert.equal(h.editor.selection.active.character, expected);
      assert.equal(h.editor.selection.isEmpty, true);
    }
  });
  test(`${language}: repeated deletion preserves text spacing, then indentation`, async () => {
    const h = harness([`  ${marker}   hello`], language);
    for (const expected of [`  ${marker}   `, "  ", ""]) {
      await h.home(true);
      assert.equal(h.lines[0], expected);
    }
  });
}

for (const [name, text, language, column, expected] of [
  ["ordinary code", "  value = 1", "python", 11, 2],
  ["empty comment", "  #   ", "python", 6, 2],
  ["bare marker", "  //", "go", 4, 2],
  ["empty doc comment", "  ///   ", "go", 8, 2],
  ["empty repeated hashes", "  ###   ", "python", 8, 2],
  ["whitespace line", "    ", "python", 4, 0],
  ["inside comment spacing", "  #   hello", "python", 5, 2],
  ["inside marker", "  // text", "go", 3, 2],
  ["inline comment", "  code() # text", "python", 15, 2],
  ["unsupported language", "  # text", "plaintext", 8, 2],
  ["wrong marker for language", "  # text", "go", 8, 2],
  ["doc comment marker", "  /// text", "go", 10, 6],
  ["repeated hash marker", "  ## text", "python", 9, 5],
  ["comment without space", "  //text", "go", 8, 4],
  ["tabs", "\t#\ttext", "python", 7, 3],
  ["bullet is content", "  # - text", "python", 10, 4],
]) {
  test(name, async () => {
    const h = harness([text], language, [column]);
    await h.home();
    assert.equal(h.editor.selection.active.character, expected);
  });
}

test("wrapped-line Home stops closer to the cursor are preserved", async () => {
  const h = harness(["  # long wrapped text"], "python", [21], 9);
  await h.home();
  assert.equal(h.editor.selection.active.character, 9);
});

test("each cursor uses its own comment or code stop", async () => {
  const h = harness(["  #   text", "    code", "#   "], "python", [10, 8, 4]);
  await h.home(true);
  assert.deepEqual(h.lines, ["  #   ", "    ", ""]);
});

test("existing selections delete directly", async () => {
  const h = harness(["  # hello"]);
  h.editor.selections = [new Selection(new Position(0, 4), new Position(0, 6))];
  await h.home(true);
  assert.equal(h.lines[0], "  # llo");
  assert.deepEqual(h.calls, ["deleteLeft"]);
});

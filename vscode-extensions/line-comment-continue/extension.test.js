const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "extension.js"), "utf8");
const context = {
  module: { exports: {} },
  require: () => ({
    EndOfLine: { CRLF: 2 },
    workspace: { getConfiguration: () => ({ get: (_key, fallback) => fallback }) },
  }),
};
vm.runInNewContext(source, context);
const { planEnter } = context.module.exports;

function enter(input, languageId = "python") {
  const offset = input.indexOf("|");
  assert.ok(offset >= 0);
  const before = input.slice(0, offset).split("\n");
  const position = { line: before.length - 1, character: before.at(-1).length };
  const text = input.replace("|", "");
  const lines = text.split("\n");
  const doc = { languageId, eol: 1, lineCount: lines.length, lineAt: (i) => ({ text: lines[i] }) };
  const plan = planEnter(doc, position);
  if (!plan) return null;
  const edits = plan.edits.map((edit) => {
    const offsetAt = ([line, column]) => lines.slice(0, line).reduce((n, text) => n + text.length + 1, column);
    return { start: offsetAt(edit.start), end: offsetAt(edit.end), text: edit.text };
  }).sort((a, b) => b.start - a.start);
  return edits.reduce((result, edit) => result.slice(0, edit.start) + edit.text + result.slice(edit.end), text);
}

for (const [name, input, expected] of [
  ["word-colon continuation", "# intro:\n#   word1: text\n#          wrapped|", "#   "],
  ["word-dash continuation", "# intro:\n#   word1 - text\n#           wrapped|", "#   "],
  ["renamed word marker", "# intro:\n#   longerName: text\n#          wrapped|", "#   "],
  ["whitespace continuation", "# intro:\n#   whitespace bullet text\n#     wrapped|", "#   "],
  ["deeper whitespace continuation", "# intro:\n#   whitespace bullet text\n#         wrapped|", "#   "],
  ["word bullet first line", "# intro:\n#   word: text|", "#   "],
  ["whitespace bullet first line", "# intro:\n#   some text|", "#   "],
  ["second word sibling", "# intro:\n#   first: text\n#   second: text\n#      wrapped|", "#   "],
  ["blank before first item", "# intro:\n#\n#   word: text\n#      wrapped|", "#   "],
  ["blank between siblings", "# intro:\n#   first: text\n#\n#   second: text\n#      wrapped|", "#   "],
  ["blank ends bullet ownership", "# intro:\n#   word: text\n#\n#      paragraph|", "#      "],
  ["word marker outside list", "# word: text\n#       wrapped|", "#       "],
  ["indented prose outside list", "# some text\n#   other text\n#     wrapped|", "#     "],
  ["shallower line ends list", "# intro:\n#   word: text\n# end\n#       paragraph|", "#       "],
  ["changed style ends list", "# intro:\n#   word: text\n#   ordinary text\n#       paragraph|", "#       "],
  ["word-dash is a different style", "# intro:\n#   word: text\n#   other - text\n#       paragraph|", "#       "],
  ["code ends list", "# intro:\n#   word: text\ncode()\n#       paragraph|", "#       "],
  ["comment block indentation boundary", "# intro:\n#   word: text\n  #       paragraph|", "  #       "],
  ["nested word list", "# intro:\n#   outer: choices:\n#            inner: text\n#                   wrapped|", "#            "],
  ["return to outer list", "# intro:\n#   outer: choices:\n#            inner: text\n#   sibling: text\n#            wrapped|", "#   "],
  ["standard nested item", "# intro:\n#   outer: choices:\n#            - text\n#              wrapped|", "#            - "],
  ["whitespace bullets absorb marker-looking content", "# intro:\n#   some text\n#     - wrapped|", "#   "],
  ["whitespace bullets do not introduce nested lists", "# intro:\n#   some text\n#     details:\n#       word: wrapped|", "#   "],
  ["word own-line content", "# intro:\n#   word:\n#     content\n#     wrapped|", "#   "],
  ["dash own-line content", "# intro:\n#   word -\n#     content\n#     wrapped|", "#   "],
  ["single-word own-line content", "# intro:\n#   word\n#     content\n#     wrapped|", "#   "],
  ["table rows are not whitespace bullets", "# intro:\n#   key  value\n#   foo  bar\n#        wrapped|", "#        "],
  ["standard bullet still repeats", "# - text\n#   wrapped|", "# - "],
  ["colon indentation still works", "# intro:|", "#   "],
  ["colon on word bullet indents beyond its text", "# intro:\n#   word: options:|", "#           "],
]) {
  test(name, () => assert.equal(enter(input), input.replace("|", "") + "\n" + expected));
}

for (const [name, input, inserted] of [
  ["word bullet with continuation below", "# intro:\n#   word: text|\n#         wrapped", "#   "],
  ["word continuation with more below", "# intro:\n#   word: text\n#         first|\n#         last", "#   "],
  ["whitespace bullet with continuation below", "# intro:\n#   some text|\n#     wrapped", "#   "],
  ["bare word marker above content", "# intro:\n#   word:|\n#     content", "#     "],
  ["bare dash marker above content", "# intro:\n#   word -|\n#     content", "#     "],
  ["single-word marker above content", "# intro:\n#   Name|\n#     content", "#     "],
  ["own-line word content with more below", "# intro:\n#   word:\n#     first|\n#     last", "#   "],
  ["own-line dash content with more below", "# intro:\n#   word -\n#     first|\n#     last", "#   "],
  ["own-line single-word content with more below", "# intro:\n#   Name\n#     first|\n#     last", "#   "],
  ["next sibling is not a continuation", "# intro:\n#   word: text|\n#   other: text", "#   "],
  ["mid-text split returns to marker column", "# intro:\n#   word: first| second", "#   "],
]) {
  test(name, () => assert.equal(enter(input), input.replace("|", "\n" + inserted)));
}

test("numeric renumbering still fills gaps", () => {
  assert.equal(enter("# 1. one\n# 2. two|\n# 4. four"), "# 1. one\n# 2. two\n# 3. \n# 4. four");
});

// Exercise the general sibling rule across every language and bullet form,
// rather than relying on the two originally reported examples.
const languages = {
  go: "//", shellscript: "#", python: "#", javascript: "//", javascriptreact: "//",
  typescript: "//", typescriptreact: "//", json: "//", jsonc: "//",
};
const bulletForms = [
  { marker: "- ", next: "- ", standard: true },
  { marker: "* ", next: "* ", standard: true },
  { marker: "9. ", next: "10. ", standard: true },
  { marker: "9) ", next: "10) ", standard: true },
  { marker: "(9) ", next: "(10) ", standard: true },
  { marker: "name: ", next: "" },
  { marker: "name - ", next: "" },
  { marker: "", next: "" },
];
for (const [language, prefix] of Object.entries(languages)) {
  for (const { marker, next, standard } of bulletForms) {
    test(`${language}: sibling position after ${marker || "whitespace"} bullet`, () => {
      const intro = `${prefix} intro:\n`;
      const head = `${prefix}   ${marker}some content`;
      const padding = " ".repeat(standard || marker ? marker.length : 2);
      const continuation = `${prefix}   ${padding}wrapped`;
      const input = `${intro}${head}\n${continuation}|`;
      assert.equal(enter(input, language), input.replace("|", `\n${prefix}   ${next}`));
      // Text below the split now belongs to the new sibling. Numeric markers
      // can grow, which shifts that text to the new sibling's text alignment.
      const remaining = standard ? `${prefix}   ${" ".repeat(next.length)}wrapped` : continuation;
      assert.equal(enter(`${intro}${head}|\n${continuation}`, language),
        `${intro}${head}\n${prefix}   ${next}\n${remaining}`);
    });
  }
}

for (const marker of ["-", "*", "9.", "9)", "(9)"]) {
  test(`standard own-line ${marker} owns deeper content`, () => {
    const next = marker === "9." ? "10." : marker === "9)" ? "10)" : marker === "(9)" ? "(10)" : marker;
    const head = `# ${marker}`;
    assert.equal(enter(`${head}\n#  content\n#  wrapped|`), `${head}\n#  content\n#  wrapped\n# ${next} `);
    assert.equal(enter(`${head}|\n#  content`), `${head}\n#  \n#  content`);
    // Truly empty standard bullets still leave the list.
    assert.equal(enter(`${head}|`), "# ");
  });
}

for (const marker of ["-", "*", "9.", "9)", "(9)"]) {
  test(`Enter below bare ${marker} preserves both accepted continuation alignments`, () => {
    const canonical = " ".repeat(marker.length + 2);
    const next = marker === "9." ? "10." : marker === "9)" ? "10)" : marker === "(9)" ? "(10)" : marker;
    for (const width of [2, 4, 7]) {
      const original = " ".repeat(width);
      const input = `# ${marker}|\n#${original}first\n#${canonical}second\n#${original}last`;
      assert.equal(enter(input), input.replace("|", `\n#${original}`));
      // Once new content is typed, both original and normal alignments still
      // belong to this item, so Enter after the last line creates its sibling.
      const typed = input.replace("|", `\n#${original}new content`);
      assert.equal(enter(typed + "|"), typed + `\n# ${next} `);
    }
  });
}

test("splitting own-line numeric content moves later continuation text with it", () => {
  assert.equal(enter("# 9.\n#  partial| rest\n#  wrapped\n# 15. later"),
    "# 9.\n#  partial\n# 10.  rest\n#     wrapped\n# 11. later");
});

for (const [current, next, later] of [["9.", "10.", "11."], ["9)", "10)", "11)"], ["(9)", "(10)", "(11)"]]) {
  test(`Enter after ${current} continuation splits the item and renumbers siblings`, () => {
    const oldPad = " ".repeat(current.length + 2);
    const newPad = " ".repeat(next.length + 2);
    const input = `# ${current} first\n#${oldPad}current|\n#${oldPad}remainder\n# ${next} later\n#${newPad}later wrap`;
    const expected = `# ${current} first\n#${oldPad}current\n# ${next} \n#${newPad}remainder\n# ${later} later\n#${newPad}later wrap`;
    assert.equal(enter(input), expected);
  });
}

test("a single-word own-line marker can start content before it exists", () => {
  assert.equal(enter("# intro:\n#   Name|"), "# intro:\n#   Name\n#     ");
  assert.equal(enter("# intro:\n#   name -|"), "# intro:\n#   name -\n#     ");
});

test("own-line word intro recognizes nested word markers at any deeper level", () => {
  assert.equal(enter("# intro:\n#   outer:\n#         inner: text\n#                wrapped|"),
    "# intro:\n#   outer:\n#         inner: text\n#                wrapped\n#         ");
});

test("the last table row inside a list retains table ownership", () => {
  for (const input of [
    "# intro:\n#   some text\n#   key  value\n#   foo  bar\n#        wrapped|",
    "# intro:\n#   word: text\n#     key  value\n#     foo  bar\n#        wrapped|",
    "# intro:\n#   word: text\n#     key:  value\n#     foo:  bar\n#        wrapped|",
  ]) assert.equal(enter(input), input.replace("|", "\n#        "));
});

test("Enter inside word and standard markers delegates to normal editing", () => {
  assert.equal(enter("# intro:\n#   na|me: text"), null);
  assert.equal(enter("# 1|. text"), null);
});

test("Enter exits the reported nested list; Backspace preserves its indentation", () => {
  const state0 = "# 1. hi\n# 2. bye\n#      1. hi\n#      2. bye";
  const state1 = state0 + "\n#      3. ";
  assert.equal(enter(state0 + "|"), state1);
  assert.equal(enter(state1 + "|"), state0 + "\n# 3. ");

  const lines = state1.split("\n");
  const plan = context.module.exports.planBackspace({
    languageId: "python", lineCount: lines.length, lineAt: (i) => ({ text: lines[i] }),
  }, { line: 4, character: lines[4].length });
  assert.equal(plan.edits.length, 1);
  const edit = plan.edits[0];
  const state2 = lines.slice(0, -1).join("\n") + "\n" +
    lines[4].slice(0, edit.start[1]) + edit.text + lines[4].slice(edit.end[1]);
  assert.equal(state2, state0 + "\n#      ");
  assert.equal(enter(state2 + "|"), state2 + "\n#      ");
});

for (const [name, input, expected] of [
  ["exit one level at a time", "# 1. outer\n#    - middle\n#         1. inner\n#         2. |",
    "# 1. outer\n#    - middle\n#         1. inner\n#    - "],
  ["unordered parent", "# * outer\n#     1. inner\n#     2. |", "# * outer\n#     1. inner\n# * "],
  ["parenthesized parent", "# (9) outer\n#       - inner\n#       - |", "# (9) outer\n#       - inner\n# (10) "],
  ["closing-parenthesis parent", "# 9) outer\n#       - inner\n#       - |", "# 9) outer\n#       - inner\n# 10) "],
  ["nonempty nested bullet still continues", "# 1. outer\n#     - inner|", "# 1. outer\n#     - inner\n#     - "],
  ["top-level empty bullet still removes marker", "# 1. outer\n# 2. |", "# 1. outer\n# "],
  ["standalone indented list has no parent", "#     - inner\n#     - |", "#     - inner\n#     "],
  ["prose closes a previous outer list", "# 1. old\n# prose\n#     - inner\n#     - |",
    "# 1. old\n# prose\n#     - inner\n#     "],
  ["code separates lists", "# 1. old\ncode()\n#     - inner\n#     - |", "# 1. old\ncode()\n#     - inner\n#     "],
  ["comment indentation separates lists", "# 1. old\n  #     - inner\n  #     - |",
    "# 1. old\n  #     - inner\n  #     "],
  ["empty marker with child content starts content", "# 1. outer\n#     - |\n#         child",
    "# 1. outer\n#     - \n#         \n#         child"],
  ["resume enclosing word list", "# intro:\n#   name: outer\n#           - inner\n#           - |",
    "# intro:\n#   name: outer\n#           - inner\n#   "],
  ["renumber outer siblings and align their wrapped text", "# 8. outer\n#      - inner\n#      - |\n# 9. later\n#    wrapped",
    "# 8. outer\n#      - inner\n# 9. \n# 10. later\n#     wrapped"],
  ["renumber remaining inner siblings too", "# 1. outer\n#     1. inner\n#     2. |\n#     3. later\n# 2. outer later",
    "# 1. outer\n#     1. inner\n# 2. \n#     2. later\n# 3. outer later"],
]) {
  test(name, () => assert.equal(enter(input), expected));
}

test("repeated Enter exits each enclosing list before removing the outermost marker", () => {
  const initial = "# 1. outer\n#    - middle\n#         1. inner\n";
  const middle = enter(initial + "#         2. |");
  assert.equal(middle, initial + "#    - ");
  const outer = enter(middle + "|");
  assert.equal(outer, initial + "# 2. ");
  assert.equal(enter(outer + "|"), initial + "# ");
});

test("resuming a parent places the cursor after the replacement marker", () => {
  const lines = ["  # 9. outer", "  #       - inner", "  #       - "];
  const plan = planEnter({
    languageId: "python", lineCount: lines.length, lineAt: (i) => ({ text: lines[i] }),
  }, { line: 2, character: lines[2].length });
  assert.equal(JSON.stringify(plan.cursor), JSON.stringify([2, "  # 10. ".length]));
});

for (const [language, prefix] of Object.entries(languages)) {
  test(`${language}: nested empty bullet resumes outer list at its actual indentation`, () => {
    const head = `\t${prefix}\t1. outer\n\t${prefix}\t\t- inner\n`;
    assert.equal(enter(head + `\t${prefix}\t\t- |`, language), head + `\t${prefix}\t2. `);
  });
}

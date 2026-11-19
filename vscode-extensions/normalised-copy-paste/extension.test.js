const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

async function paste(input, clipboard, languageId) {
  const offset = input.indexOf('|');
  const endOffset = input.indexOf('|', offset + 1);
  const text = input.replaceAll('|', '');
  const positionAt = (offset) => {
    const lines = text.slice(0, offset).split('\n');
    return { line: lines.length - 1, character: lines.at(-1).length };
  };
  const selection = {
    start: positionAt(offset),
    end: positionAt(endOffset < 0 ? offset : endOffset - 1),
  };
  const commands = {};
  const context = {
    module: { exports: {} },
    require: () => ({
      commands: { registerTextEditorCommand: (name, fn) => { commands[name] = fn; } },
      env: { clipboard: { readText: async () => clipboard } },
    }),
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'extension.js'), 'utf8'), context);
  context.module.exports.activate({ subscriptions: [] });
  let result;
  await commands['normalisedCopyPaste.paste']({
    document: { languageId, lineAt: (i) => ({ text: text.split('\n')[i] }) },
    selections: [selection],
    edit: async (fn) => fn({ replace: (_range, replacement) => {
      result = text.slice(0, offset) + replacement + text.slice(endOffset < 0 ? offset : endOffset - 1);
    } }),
  });
  return result;
}

for (const [languageId, marker] of [['javascript', '//'], ['python', '#']]) {
  test(`${languageId}: trailing newline keeps existing text commented`, async () => {
    assert.equal(
      await paste(`  ${marker}   |existing explanation`, `${marker} first paragraph\n`, languageId),
      `  ${marker}   first paragraph\n  ${marker}   existing explanation`,
    );
  });

  test(`${languageId}: plain clipboard text keeps existing text commented`, async () => {
    assert.equal(
      await paste(`${marker} |existing explanation`, 'first paragraph\n', languageId),
      `${marker} first paragraph\n${marker} existing explanation`,
    );
  });

  test(`${languageId}: multiline selection uses text after the selection end`, async () => {
    assert.equal(
      await paste(`${marker} |remove\n${marker} remove|existing explanation`, `${marker} replacement\n`, languageId),
      `${marker} replacement\n${marker} existing explanation`,
    );
  });

  test(`${languageId}: end-of-line paste leaves no trailing marker`, async () => {
    assert.equal(await paste(`${marker} |`, `${marker} first\n`, languageId), `${marker} first\n`);
  });

  test(`${languageId}: paragraph breaks retain bare markers`, async () => {
    assert.equal(
      await paste(`${marker} |existing`, `${marker} first\n\n${marker} second\n`, languageId),
      `${marker} first\n${marker}\n${marker} second\n${marker} existing`,
    );
  });

  test(`${languageId}: paste without trailing newline adds no extra prefix`, async () => {
    assert.equal(await paste(`${marker} |existing`, `${marker} first `, languageId), `${marker} first existing`);
  });
}

test('paste into code preserves indentation without adding comment markers', async () => {
  assert.equal(await paste('  |existing', 'first\nsecond\n', 'javascript'), '  first\n  second\nexisting');
});

const vscode = require("vscode");
const { execFile } = require("child_process");
const fs = require("fs");
const { parse, printParseErrorCode } = require("jsonc-parser");
const os = require("os");
const path = require("path");
const { LiveReflow } = require("./live");
const { LiveFormatter } = require("./live-formatter");

function configFile() {
  return process.env.COMMENT_WRAP_CONFIG || path.join(os.homedir(), "comment-wrap", "config.jsonc");
}

function loadConfig() {
  const errors = [];
  const config = parse(fs.readFileSync(configFile(), "utf8"), errors, { allowTrailingComma: true });
  if (errors.length) {
    const { error, offset } = errors[0];
    throw new Error(`parse ${configFile()}: ${printParseErrorCode(error)} at offset ${offset}`);
  }
  if (!config.languages || Object.keys(config.languages).length === 0) {
    throw new Error("no languages configured");
  }
  const languages = {};
  for (const [id, overrides] of Object.entries(config.languages)) {
    const language = { tableGap: 2, ...config.defaults, ...overrides };
    for (const key of ["width", "tabWidth", "minColWidth"]) {
      if (!Number.isInteger(language[key]) || language[key] < 1) {
        throw new Error(`${key} for ${id} must be a positive integer`);
      }
    }
    if (!Number.isInteger(language.tableGap) || language.tableGap < 2) {
      throw new Error(`tableGap for ${id} must be an integer of at least 2`);
    }
    if (typeof language.formatter !== "string" || !language.formatter) {
      throw new Error(`missing formatter configuration for ${id}`);
    }
    if (language.args !== undefined && (!Array.isArray(language.args) || language.args.some((arg) => typeof arg !== "string"))) {
      throw new Error(`formatter args for ${id} must be strings`);
    }
    languages[id] = language;
  }
  return languages;
}

function runFormatter(document, language, options) {
  const formatter = path.join(os.homedir(), ".local", "bin", language.formatter);
  const tabSize = options?.tabSize ?? vscode.workspace.getConfiguration("editor", document).get("tabSize");
  return new Promise((resolve, reject) => {
    const command = execFile(formatter, language.args || [], {
      maxBuffer: 10 * 1024 * 1024,
      env: {
        ...process.env,
        COMMENT_WRAP_CONFIG: configFile(),
        COMMENT_WRAP_LANGUAGE: document.languageId,
        COMMENT_WRAP_TAB_WIDTH: String(tabSize),
      },
    }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(stderr || error.message));
      } else {
        resolve(stdout);
      }
    });
    // A formatter that exits before consuming stdin reports its useful error via
    // execFile's callback; don't let a subsequent EPIPE crash the extension host.
    command.stdin.on("error", () => {});
    command.stdin.end(document.getText());
  });
}

function editsFor(document, formatted) {
  if (formatted === document.getText()) {
    return [];
  }
  return [vscode.TextEdit.replace(
    new vscode.Range(document.positionAt(0), document.positionAt(document.getText().length)),
    formatted,
  )];
}

function activate(context) {
  const output = vscode.window.createOutputChannel("Comment Wrap");
  const formatter = new LiveFormatter(path.join(os.homedir(), ".local", "bin", "live-comment-wrap"));
  const live = new LiveReflow((document, request) => formatter.run(document, request), loadConfig, (error) => output.appendLine(`Live reflow: ${error.message}`));
  let previousEditor = vscode.window.activeTextEditor;
  context.subscriptions.push(
    output, formatter, live,
    vscode.workspace.onDidChangeTextDocument((event) => live.changed(event)),
    vscode.workspace.onDidCloseTextDocument((document) => live.close(document)),
    vscode.window.onDidChangeTextEditorSelection((event) => live.selected(event)),
    vscode.window.onDidChangeActiveTextEditor((editor) => {
      if (previousEditor && previousEditor !== editor) live.leave(previousEditor);
      previousEditor = editor;
    }),
    vscode.workspace.onDidChangeConfiguration(() => {
      for (const document of live.states.keys()) live.reset(document);
    }),
  );
  let providers = [];
  const registerProviders = () => {
    try {
      const languages = loadConfig();
      const replacements = Object.keys(languages).map((languageId) =>
        vscode.languages.registerDocumentFormattingEditProvider(languageId, {
          provideDocumentFormattingEdits(document, options, token) {
            live.reset(document);
            if (token.isCancellationRequested) {
              return [];
            }
            const language = loadConfig()[languageId];
            if (!language) {
              return [];
            }
            const version = document.version;
            return runFormatter(document, language, options).then((formatted) =>
              token.isCancellationRequested || document.version !== version ? [] : editsFor(document, formatted));
          },
        }));
      providers.forEach((provider) => provider.dispose());
      providers = replacements;
    } catch (error) {
      vscode.window.showErrorMessage(`Comment Wrap: ${error.message}`);
    }
  };
  registerProviders();
  // Adding a language only requires a config entry, even in an open window.
  const watcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(path.dirname(configFile()), path.basename(configFile())));
  context.subscriptions.push(
    watcher,
    watcher.onDidChange(registerProviders),
    watcher.onDidCreate(registerProviders),
    watcher.onDidDelete(registerProviders),
    { dispose: () => providers.forEach((provider) => provider.dispose()) },
  );
  return { protectEnter: (document, change) => live.protectEnter(document, change) };
}

function deactivate() {}

module.exports = { activate, deactivate };

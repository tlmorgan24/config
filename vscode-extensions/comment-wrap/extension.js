const vscode = require("vscode");
const { execFile } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

function loadLanguageConfig(languageId) {
  const configFile = path.join(os.homedir(), ".config", "comment-wrap", "config.json");
  const config = JSON.parse(fs.readFileSync(configFile, "utf8"));
  const language = config[languageId];
  if (!language || typeof language.enabled !== "boolean") {
    throw new Error(`missing configuration for ${languageId}`);
  }
  return language;
}

function runFormatter(document, languageId) {
  const formatterName = languageId === "go"
    ? "go-comment-wrap"
    : languageId === "shellscript"
      ? "shell-comment-wrap"
      : languageId === "python"
        ? "python-comment-wrap"
        : "js-comment-wrap";
  const formatter = path.join(os.homedir(), ".local", "bin", formatterName);
  return new Promise((resolve, reject) => {
    execFile(formatter, [languageId], { maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(stderr || error.message));
      } else {
        resolve(stdout);
      }
    }).stdin.end(document.getText());
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

function formatOnSave(event) {
  const languageId = event.document.languageId;
  if (!supportedLanguages.includes(languageId)) {
    return;
  }

  let language;
  try {
    language = loadLanguageConfig(languageId);
  } catch (error) {
    vscode.window.showErrorMessage(`Comment Wrap: ${error.message}`);
    return;
  }
  if (!language.enabled) {
    return;
  }

  event.waitUntil(
    runFormatter(event.document, languageId)
      .then((formatted) => editsFor(event.document, formatted))
      .catch((error) => {
        vscode.window.showErrorMessage(`Comment Wrap: ${error.message}`);
        return [];
      }),
  );
}

function activate(context) {
  for (const languageId of supportedLanguages) {
    context.subscriptions.push(vscode.languages.registerDocumentFormattingEditProvider(languageId, {
      provideDocumentFormattingEdits(document, options, token) {
        if (token.isCancellationRequested) {
          return [];
        }
        let language;
        try {
          language = loadLanguageConfig(languageId);
        } catch (error) {
          return Promise.reject(error);
        }
        if (!language.enabled) {
          return [];
        }
        return runFormatter(document, languageId).then((formatted) => editsFor(document, formatted));
      },
    }));
  }
  context.subscriptions.push(vscode.workspace.onWillSaveTextDocument(formatOnSave));
}

const supportedLanguages = [
  "go", "shellscript", "python", "javascript", "javascriptreact",
  "typescript", "typescriptreact", "json", "jsonc",
];

function deactivate() {}

module.exports = { activate, deactivate };

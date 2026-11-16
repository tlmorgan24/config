const vscode = require("vscode");
const { execFile } = require("child_process");
const os = require("os");
const path = require("path");

function activate(context) {
  const provider = vscode.languages.registerDocumentFormattingEditProvider("shellscript", {
    provideDocumentFormattingEdits(document, options, token) {
      return new Promise((resolve, reject) => {
        const formatter = path.join(os.homedir(), ".local", "bin", "shell-comment-wrap");
        execFile(formatter, [], { maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
          if (token.isCancellationRequested) {
            resolve([]);
          } else if (error) {
            reject(new Error(stderr || error.message));
          } else {
            resolve([vscode.TextEdit.replace(
              new vscode.Range(document.positionAt(0), document.positionAt(document.getText().length)),
              stdout,
            )]);
          }
        }).stdin.end(document.getText());
      });
    },
  });
  context.subscriptions.push(provider);
}

function deactivate() {}

module.exports = { activate, deactivate };

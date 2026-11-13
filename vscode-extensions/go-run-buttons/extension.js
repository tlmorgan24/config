// Add a "run" button to Go files, similarly to what the Python extension already does
// for Python files (including dropdown to choose between simple run or run+debug).
// A simple run does `go run .` in the directory of the current file, while
// run+debug starts VS Code's debugger.
const path = require('path');
const vscode = require('vscode');

const terminalName = 'Go Run';

function getActiveGoFile() {
  const editor = vscode.window.activeTextEditor;
  if (!editor || editor.document.languageId !== 'go') {
    vscode.window.showErrorMessage('Open a Go file to run or debug its package.');
    return undefined;
  }
  return editor.document.uri.fsPath;
}

function activate(context) {
  let terminal;
  let terminalCwd;

  const run = vscode.commands.registerCommand('goRunButtons.run', () => {
    const file = getActiveGoFile();
    if (!file) {
      return;
    }

    const cwd = path.dirname(file);
    if (!terminal || terminal.exitStatus !== undefined || terminalCwd !== cwd) {
      terminal = vscode.window.createTerminal({ name: terminalName, cwd });
      terminalCwd = cwd;
    }
    terminal.show();
    terminal.sendText('go run .');
  });

  const debug = vscode.commands.registerCommand('goRunButtons.debug', async () => {
    const file = getActiveGoFile();
    if (!file) {
      return;
    }

    const started = await vscode.debug.startDebugging(undefined, {
      type: 'go',
      name: 'Debug Go Package',
      request: 'launch',
      mode: 'debug',
      program: path.dirname(file),
    });
    if (!started) {
      vscode.window.showErrorMessage(
        'Unable to start Go debugging. Install or enable the Go extension first.'
      );
    }
  });

  context.subscriptions.push(run, debug);
}

function deactivate() {}

module.exports = { activate, deactivate };

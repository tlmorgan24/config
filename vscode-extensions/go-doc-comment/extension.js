const vscode = require("vscode");
const { execFile } = require("child_process");
const os = require("os");
const path = require("path");

function toRange(edit) {
  return new vscode.Range(edit.start[0], edit.start[1], edit.end[0], edit.end[1]);
}

function docCommentTarget(editor) {
  if (!editor || editor.document.languageId !== "go" || editor.selections.length !== 1 || !editor.selection.isEmpty) {
    return null;
  }
  const position = editor.selection.active;
  const line = editor.document.lineAt(position.line).text;
  const match = line.match(/^(\s*)\/\/$/);
  if (!match || position.character !== line.length || position.line + 1 >= editor.document.lineCount) {
    return null;
  }
  return { line: position.line, indentation: match[1] };
}

function readGoDeclaration(source, line) {
  return new Promise((resolve, reject) => {
    const command = execFile(path.join(os.homedir(), ".local", "bin", "go-doc-comment"), [], {
      timeout: 2000,
      maxBuffer: 1024 * 1024,
    }, (error, stdout) => {
      if (error) {
        reject(error);
        return;
      }
      try {
        resolve(JSON.parse(stdout));
      } catch (error) {
        reject(error);
      }
    });
    command.stdin.on("error", () => {});
    command.stdin.end(JSON.stringify({ source, line }));
  });
}

function docCommentPlan(target, signature, eol) {
  const overview = `${target.indentation}// ${signature.name} `;
  const text = [overview, ...signature.names.map((name) => `${target.indentation}//   - ${name}: `)].join(eol);
  return {
    edits: [{ start: [target.line, 0], end: [target.line, target.indentation.length + 3], text }],
    cursor: [target.line, overview.length],
  };
}

async function slash() {
  const editor = vscode.window.activeTextEditor;
  const target = docCommentTarget(editor);
  // Insert immediately, so ordinary typing and failed/stale generation keep the slash.
  await vscode.commands.executeCommand("default:type", { text: "/" });
  if (!target || vscode.window.activeTextEditor !== editor) {
    return;
  }
  const document = editor.document;
  const version = document.version;
  const selection = editor.selection;
  if (selection.active.line !== target.line || selection.active.character !== target.indentation.length + 3 ||
      document.lineAt(target.line).text !== `${target.indentation}///`) {
    return;
  }
  try {
    const signature = await readGoDeclaration(document.getText(), target.line + 2);
    if (!signature || document.version !== version || vscode.window.activeTextEditor !== editor ||
        editor.selections.length !== 1 || !editor.selection.isEqual(selection)) {
      return;
    }
    const plan = docCommentPlan(target, signature, document.eol === vscode.EndOfLine.CRLF ? "\r\n" : "\n");
    const applied = await editor.edit((builder) => {
      for (const edit of plan.edits) {
        builder.replace(toRange(edit), edit.text);
      }
    }, { undoStopBefore: false, undoStopAfter: true });
    if (applied) {
      editor.selection = new vscode.Selection(...plan.cursor, ...plan.cursor);
    }
  } catch (error) {
    vscode.window.showErrorMessage(`Go doc comment: ${error.message}. Run ./copy.sh to install go-doc-comment.`);
  }
}

function activate(context) {
  context.subscriptions.push(vscode.commands.registerCommand("goDocComment.slash", slash));
}

function deactivate() {}

module.exports = { activate, deactivate, docCommentTarget, docCommentPlan, slash };

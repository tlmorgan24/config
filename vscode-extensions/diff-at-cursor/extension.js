const vscode = require('vscode');

exports.activate = (context) => {
  context.subscriptions.push(
    vscode.commands.registerCommand('diffAtCursor.toggle', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const selection = editor.selection;
      const inDiff =
        vscode.window.tabGroups.activeTabGroup.activeTab?.input instanceof
        vscode.TabInputTextDiff;

      if (inDiff) {
        // Back to the normal editor at the same cursor position
        await vscode.commands.executeCommand('git.openFile');
      } else {
        await vscode.commands.executeCommand('git.openChange', editor.document.uri);
      }

      const target = vscode.window.activeTextEditor;
      if (target) {
        target.selection = selection;
        target.revealRange(selection, vscode.TextEditorRevealType.InCenter);
      }
    })
  );
};
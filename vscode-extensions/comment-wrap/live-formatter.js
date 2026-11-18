const { spawn } = require("child_process");

// One persistent helper avoids process startup on every keystroke. Requests
// run serially; a document can have at most one pending snapshot, replaced by
// its newest edit. LiveReflow rejects results for obsolete document versions.
class LiveFormatter {
  constructor(executable, { timeout = 2000 } = {}) {
    Object.assign(this, { executable, timeout, pending: new Map(), child: null, active: null, disposed: false });
  }

  run(document, request) {
    if (this.disposed) return Promise.resolve(null);
    return new Promise((resolve, reject) => {
      this.pending.get(document)?.resolve(null);
      this.pending.set(document, { request, resolve, reject });
      this.pump();
    });
  }

  start() {
    const child = spawn(this.executable, [], { stdio: ["pipe", "pipe", "pipe"] });
    this.child = child;
    let output = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk) => { stderr = (stderr + chunk).slice(-8192); });
    child.on("error", (error) => { if (this.child === child) this.fail(error); });
    child.stdin.on("error", (error) => { if (this.child === child) this.fail(error); });
    child.on("exit", (code, signal) => {
      if (this.child === child) this.fail(new Error(stderr || `Live formatter exited (${signal || code})`));
    });
    child.stdout.on("data", (chunk) => {
      if (this.child !== child) return;
      output += chunk;
      if (output.length > 10 * 1024 * 1024) return this.fail(new Error("Live formatter response exceeds 10 MB"));
      let newline;
      while ((newline = output.indexOf("\n")) !== -1) {
        const line = output.slice(0, newline);
        output = output.slice(newline + 1);
        const active = this.active;
        if (!active) return this.fail(new Error("Unexpected live formatter response"));
        let result;
        try { result = JSON.parse(line); } catch (error) { return this.fail(error); }
        clearTimeout(this.requestTimeout);
        this.active = null;
        active.resolve(result);
        this.pump();
      }
    });
  }

  pump() {
    if (this.active || !this.pending.size || this.disposed) return;
    try {
      if (!this.child) this.start();
      const [document, active] = this.pending.entries().next().value;
      this.pending.delete(document);
      this.active = active;
      // A hung-helper deadline, unrelated to when typing triggers reflow.
      this.requestTimeout = setTimeout(() => this.fail(new Error("Live formatter timed out")), this.timeout);
      this.child.stdin.write(JSON.stringify(active.request) + "\n");
    } catch (error) {
      this.fail(error);
    }
  }

  fail(error) {
    this.stop((item) => item.reject(error));
  }

  stop(settle) {
    clearTimeout(this.requestTimeout);
    const child = this.child;
    this.child = null;
    child?.kill();
    if (this.active) settle(this.active);
    this.active = null;
    for (const item of this.pending.values()) settle(item);
    this.pending.clear();
  }

  dispose() {
    this.disposed = true;
    this.stop((item) => item.resolve(null));
  }
}

module.exports = { LiveFormatter };

#!/usr/bin/env python3
"""Shared, cached search for the fzf tools. Run via _fzf_search in .zshrc.

The collector owns the source process independently of fzf's reload processes, so
typing never restarts fd (or interrupts a source that's still streaming). Normal
insensitive searches stay in the UI's native matcher. fzf's filter mode supplies
case-sensitive matches when requested; rg supplies linear-time regexes.
Only snapshots cross the socket. Neither queries nor results become shell code.
"""

import json
import os
from pathlib import Path
import re
import signal
import socket
import socketserver
import subprocess
import sys
import tempfile
import threading
import time


ANSI = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")
HERE = Path(__file__).resolve().parent


def match(rows, query, prompt, sensitive, nth, scheme):
    if not rows:
        return b""
    if not query:
        return b"".join(rows)
    env = dict(os.environ, FZF_QUERY=query, FZF_PROMPT=prompt,
               FZF_DEFAULT_OPTS="", FZF_DEFAULT_OPTS_FILE="")
    if prompt.startswith("regex"):
        # Search the same original TSV fields as fzf, without colour escapes.
        start = int(nth.rstrip(".")) - 1
        texts = [b"\t".join(ANSI.sub(b"", row).rstrip(b"\n").split(b"\t")[start:])
                 for row in rows]
        result = subprocess.run(
            ["rg", "--no-config", "--color=never", "--line-number", "--no-heading",
             "--case-sensitive" if sensitive else "--ignore-case", "-e", query],
            input=b"\n".join(texts) + b"\n", stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        # Invalid/incomplete regexes simply have no matches while being edited.
        if result.returncode:
            return b""
        return b"".join(rows[int(line.split(b":", 1)[0]) - 1]
                        for line in result.stdout.splitlines())
    rewritten = subprocess.run(
        ["zsh", "-f", str(HERE / "fzf-search-mode.zsh")], env=env,
        stdout=subprocess.PIPE, check=True).stdout.decode().rstrip("\n")
    # fzf --filter --ansi removes colour escapes from output. Return row indexes
    # instead, then emit the untouched rows so previews and coloured labels survive.
    indexed = b"".join(str(index).encode() + b"\t" + row for index, row in enumerate(rows))
    field = str(int(nth.rstrip(".")) + 1) + (".." if nth.endswith("..") else "")
    indexes = subprocess.run(
        ["fzf", "--ansi", f"--nth={field}", "--delimiter=\t", f"--scheme={scheme}",
         "--accept-nth=1",
         "--tiebreak=index",
         "+i" if sensitive else "-i", f"--filter={rewritten}"],
        input=indexed, stdout=subprocess.PIPE, env=env).stdout
    return b"".join(rows[int(index)] for index in indexes.splitlines())


class Cache:
    def __init__(self, nth, scheme):
        self.nth, self.scheme = nth, scheme
        self.lock = threading.Lock()
        self.rows = []
        self.process = None
        self.loading = False
        self.revision = 0
        self.sent = -1
        self.source_lock = threading.Lock()
        self.closed = False

    def _stop(self):
        if self.process is not None:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            self.process.wait()

    def stop(self):
        with self.source_lock:
            self.closed = True
            self._stop()

    def source(self, command):
        with self.source_lock:
            if self.closed:
                return
            self._stop()
            process = subprocess.Popen(
                ["zsh", "-fc", command], stdout=subprocess.PIPE, start_new_session=True)
            with self.lock:
                self.process = process
                self.rows = []
                self.loading = True
                self.revision += 1

        def collect():
            try:
                for row in process.stdout:
                    with self.lock:
                        if self.process is not process:
                            return
                        self.rows.append(row)
                        self.revision += 1
            finally:
                process.stdout.close()
                process.wait()
                with self.lock:
                    if self.process is process:
                        self.loading = False
                        self.revision += 1

        threading.Thread(target=collect, daemon=True).start()

    def request(self, request):
        action = request["action"]
        if action == "set-source":
            self.source(request["command"])
            return b""
        if action == "poll":
            with self.lock:
                refresh = self.loading or self.sent != self.revision
            if refresh:
                time.sleep(0.08)
                return b'reload(python3 "$FZF_SEARCH_HELPER" query)\n'
            return b""
        with self.lock:
            rows, revision = self.rows[:], self.revision
        if not request["sensitive"] and not request["prompt"].startswith("regex"):
            result = b"".join(rows)  # Let the UI match, rank and highlight natively.
        else:
            result = match(rows, request["query"], request["prompt"], request["sensitive"],
                           self.nth, self.scheme)
        with self.lock:
            self.sent = revision
        return result


def client(action, command=None):
    state = Path(os.environ["FZF_SEARCH_STATE"])
    if action == "toggle-case":
        flag = state / "case-sensitive"
        if flag.exists():
            flag.unlink()
        else:
            flag.touch()
        return
    request = dict(action=action, command=command, query=os.environ.get("FZF_QUERY", ""),
                   prompt=os.environ.get("FZF_PROMPT", "fuzzy> "),
                   sensitive=(state / "case-sensitive").exists())
    with socket.socket(socket.AF_UNIX) as connection:
        connection.connect(str(state / "socket"))
        connection.sendall(json.dumps(request).encode() + b"\n")
        while data := connection.recv(65536):
            sys.stdout.buffer.write(data)


def run(command, nth, scheme, options):
    cache = Cache(nth, scheme)

    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            try:
                result = cache.request(json.loads(self.rfile.readline()))
                self.wfile.write(result)
            except (BrokenPipeError, ConnectionResetError):
                pass  # fzf cancelled an obsolete reload.

    # macOS limits Unix socket paths to 104 bytes; TMPDIR can already be long.
    with tempfile.TemporaryDirectory(prefix="fzf-search-", dir="/tmp") as state:
        env = dict(os.environ, FZF_SEARCH_STATE=state, FZF_SEARCH_HELPER=str(HERE / "fzf-search.py"))
        # Sources use the same environment as fzf's reload commands.
        os.environ.update(FZF_SEARCH_STATE=state, FZF_SEARCH_HELPER=env["FZF_SEARCH_HELPER"])
        with socketserver.ThreadingUnixStreamServer(str(Path(state) / "socket"), Handler) as server:
            server.daemon_threads = True
            threading.Thread(target=server.serve_forever, daemon=True).start()
            cache.source(command)
            try:
                return subprocess.call(
                    ["fzf", *options,
                     '--bind=start:+reload(python3 "$FZF_SEARCH_HELPER" query)'], env=env)
            finally:
                cache.stop()
                server.shutdown()


if __name__ == "__main__":
    try:
        if sys.argv[1] == "run":
            sys.exit(run(*sys.argv[2:5], sys.argv[5:]))
        client(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    except BrokenPipeError:
        # A newer query has replaced this reload.
        sys.stdout = open(os.devnull, "w")

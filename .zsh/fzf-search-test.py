"""Run with python3 .zsh/fzf-search-test.py (requires fzf, rg, and zsh)."""

import fcntl
import importlib.util
import http.client
import json
import os
from pathlib import Path
import pty
import re
import socket
import signal
import struct
import subprocess
import tempfile
import termios
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("search", ROOT / ".zsh/fzf-search.py")
search = importlib.util.module_from_spec(spec)
spec.loader.exec_module(search)


class Matching(unittest.TestCase):
    rows = [b"hidden\tdate\t0\t\x1b[31mGit Push\x1b[0m\n",
            b"hidden\tdate\t0\tgit pull\n", b"hidden\tdate\t0\tgit push\n"]

    def test_modes_and_case(self):
        for mode, query in [("fuzzy", "GP"), ("words", "Git Push"),
                            ("phrase", "Git P"), ("regex", "^Git (Push|pull)$")]:
            with self.subTest(mode=mode):
                loose = search.match(self.rows, query, mode, False, "4..", "history")
                strict = search.match(self.rows, query, mode, True, "4..", "history")
                self.assertIn(self.rows[0], loose)
                self.assertEqual(strict, self.rows[0])
                self.assertNotEqual(loose, strict)

    def test_regex_fields_ansi_errors_and_order(self):
        self.assertEqual(search.match([], "^$", "regex", False, "4..", "history"), b"")
        self.assertEqual(search.match(self.rows, "hidden", "regex", False, "4..", "history"), b"")
        self.assertEqual(search.match(self.rows, "[", "regex", False, "4..", "history"), b"")
        self.assertEqual(search.match(self.rows, "^git", "regex", False, "4..", "history"),
                         b"".join(self.rows))

    def test_source_keeps_streaming_between_snapshots(self):
        cache = search.Cache("2..", "history")
        with tempfile.TemporaryDirectory(dir="/tmp") as tmp:
            calls = Path(tmp) / "calls"
            cache.source(f"echo run >> {calls}; printf 'id\\tfirst\\n'; sleep 0.2; printf 'id\\tsecond\\n'")
            try:
                request = dict(action="query", query="", prompt="regex", sensitive=False)
                deadline = time.monotonic() + 3
                while cache.loading and time.monotonic() < deadline:
                    cache.request(request)
                    time.sleep(0.02)
                self.assertEqual(cache.request(request), b"id\tfirst\nid\tsecond\n")
                self.assertEqual(calls.read_text(), "run\n")
            finally:
                cache.stop()


class Interactive(unittest.TestCase):
    extra_functions = []

    def program(self):
        return r'''
_fzf_help ⌃s mode ⌃i insensitive
opts=($reply)
_fzf_search_mode_opts
opts+=($reply)
_fzf_search "printf 'id\\tAlpha\\nid\\talpha\\n'" 2.. history "${opts[@]}" \
  --delimiter=$'\t' --with-nth=2.. --accept-nth=1
'''

    def setUp(self):
        self.expected_query = ""
        self.tmp = tempfile.TemporaryDirectory(dir="/tmp")
        self.home = Path(self.tmp.name)
        (self.home / ".zsh").symlink_to(ROOT / ".zsh", target_is_directory=True)
        rc = (ROOT / ".zshrc").read_text()
        functions = []
        for name in ["_fzf_help", "_fzf_search", "_fzf_search_mode_opts", *self.extra_functions]:
            definition = re.search(r"(?m)^([ \t]*)" + re.escape(name) + r"\(\) \{", rc)
            start = definition.start()
            closing = "\n" + definition[1] + "}"
            functions.append(rc[start:rc.index(closing, start) + len(closing)])
        self.ui = str(self.home / "ui.sock")
        script = "\n".join(functions) + "\n" + self.program()
        (self.home / "run.zsh").write_text(script)
        self.master, self.slave = pty.openpty()
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", 36, 160, 0, 0))
        def terminal_session():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)
        env = dict(os.environ, HOME=str(self.home), TERM="xterm-256color",
                   COLORTERM="truecolor", FZF_DEFAULT_OPTS=f"--border --listen={self.ui} --preview-window=hidden",
                   PATH=str(ROOT / ".local/bin") + os.pathsep + os.environ["PATH"])
        env.pop("NO_COLOR", None)
        self.process = subprocess.Popen(
            ["zsh", "-f", str(self.home / "run.zsh")], stdin=self.slave, stderr=self.slave,
            stdout=subprocess.PIPE, preexec_fn=terminal_session, env=env)
        self.output = bytearray()
        def drain():
            try:
                while chunk := os.read(self.master, 65536):
                    self.output.extend(chunk)
            except OSError:
                pass
        threading.Thread(target=drain, daemon=True).start()
        deadline = time.monotonic() + 5
        while not Path(self.ui).exists():
            if self.process.poll() is not None or time.monotonic() > deadline:
                self.fail("fzf failed to start: " + self.terminal())
            time.sleep(0.02)

    def terminal(self):
        return self.output.decode(errors="replace")

    def request(self, action=None):
        if action and action.startswith("change-query("):
            self.expected_query = action[len("change-query("):-1]
        connection = http.client.HTTPConnection("localhost", timeout=5)
        connection.sock = socket.socket(socket.AF_UNIX)
        connection.sock.settimeout(5)
        connection.sock.connect(self.ui)
        connection.request("POST" if action else "GET", "/", body=action)
        response = connection.getresponse()
        body = response.read()
        connection.close()
        self.assertEqual(response.status, 200, body)
        if not action:
            return json.loads(body)

    def wait_for(self, count, prompt=None):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            state = self.request()
            if (state["matchCount"] == count and state["query"] == self.expected_query
                    and (prompt is None or prompt.rstrip() in self.terminal())):
                return state
            time.sleep(0.04)
        self.fail(f"Unexpected UI state: {state}; terminal: {self.terminal()}")

    def tearDown(self):
        if hasattr(self, "process"):
            if self.process.poll() is None:
                try:
                    self.request("abort")
                except (OSError, AssertionError):
                    os.killpg(self.process.pid, signal.SIGTERM)
            try:
                self.process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.communicate()
            os.close(self.master)
            os.close(self.slave)
        self.tmp.cleanup()

    def test_cycle_case_help_and_reload(self):
        self.wait_for(2, "fuzzy> ")
        deadline = time.monotonic() + 3
        while "insensitive" not in self.terminal() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertIn("166;227;161", self.terminal())
        self.request("change-query(ALPHA)")
        self.wait_for(2)
        self.request("trigger(ctrl-i)")
        self.wait_for(0)
        self.request("change-query(Alpha)")
        self.wait_for(1)
        for mode in ["words", "phrase", "regex", "fuzzy"]:
            self.request("trigger(ctrl-s)")
            self.wait_for(1, mode + "> ")
            if mode == "regex":
                self.request("change-query(^(Alpha|beta)$)")
                self.wait_for(1)
                self.request("change-query([)")
                self.wait_for(0)
                self.request("change-query(Alpha)")
                self.wait_for(1)
        self.request("trigger(ctrl-i)")
        self.wait_for(2)
        self.request("execute-silent(python3 \"$FZF_SEARCH_HELPER\" set-source \"printf 'new\\tALPHA\\n'\")"
                     "+reload(python3 \"$FZF_SEARCH_HELPER\" query)")
        self.wait_for(1)


class Browse(Interactive):
    extra_functions = ["browse"]

    def program(self):
        directory = self.home / "files"
        directory.mkdir()
        (directory / "Alpha.txt").touch()
        (directory / "alpha.go").touch()
        (directory / "child").mkdir()
        (directory / "child/needle.txt").touch()
        return 'browse "$HOME/files"\n'

    def test_cycle_case_help_and_reload(self):
        self.wait_for(3, "fuzzy> ")
        self.request("change-query(alpha)")
        self.wait_for(2)
        self.request("trigger(ctrl-i)")
        self.wait_for(1)
        for mode in ["words", "phrase", "regex"]:
            self.request("trigger(ctrl-s)")
            self.wait_for(1, mode + "> ")
        self.request("change-query(^alpha\\.go$)")
        self.wait_for(1)
        self.request("trigger(ctrl-space)")
        self.wait_for(1)
        self.request("change-query(needle)")
        self.wait_for(0)
        self.request("trigger(ctrl-r)")
        self.wait_for(1)
        self.request("trigger(left)")
        self.wait_for(1)
        self.request("accept")
        output, _ = self.process.communicate(timeout=5)
        self.assertEqual(output.decode().strip(), str((self.home / "files/alpha.go").resolve()))


class History(Interactive):
    extra_functions = ["cmdlog-history-widget"]

    def program(self):
        binary = self.home / "bin/cmdlog"
        binary.parent.mkdir()
        binary.write_text('''#!/bin/sh
case "$1" in
  search)
    if [ "$2" = --here ]; then
      printf 'here\\tdate\\t0\\tGit Here\\n'
    else
      printf 'all\\tdate\\t0\\tGit Push\\nother\\tdate\\t0\\talpha\\n'
    fi ;;
  get) printf 'command-%s' "$2" ;;
esac
''')
        binary.chmod(0o755)
        return '''
export PATH="$HOME/bin:$PATH"
_save_highlight_context() { REPLY=$(mktemp) }
zle() { : }
cmdlog-history-widget
print -r -- "$LBUFFER"
'''

    def test_cycle_case_help_and_reload(self):
        self.wait_for(2, "fuzzy> ")
        self.request("change-query(git)")
        self.wait_for(1)
        self.request("trigger(ctrl-i)")
        self.wait_for(0)
        self.request("trigger(ctrl-i)")
        self.wait_for(1)
        os.write(self.master, b"\x12")  # The binding uses FZF_KEY to distinguish Ctrl+r from Ctrl+t.
        self.wait_for(1)
        for mode in ["words", "phrase", "regex"]:
            self.request("trigger(ctrl-s)")
            self.wait_for(1, mode + "> ")
        self.request("change-query(^git here$)")
        self.wait_for(1)
        os.write(self.master, b"\x14")
        self.wait_for(1)
        self.request("accept")
        output, _ = self.process.communicate(timeout=5)
        self.assertEqual(output.decode().strip(), "command-here")


class Claude(Interactive):
    extra_functions = ["claude-search"]

    def program(self):
        for name, directory in [("here", str(ROOT)), ("elsewhere", "/elsewhere")]:
            transcript = self.home / "transcripts" / name / "session.md"
            transcript.parent.mkdir(parents=True)
            transcript.write_text(f"# Session\n\n2026-11-18 12:00 · {directory} · session-{name}\n\n"
                                  f"## Me · 12:00\n\nGit {name}\n")
        return '''
claude-transcripts() { print -r -- "$HOME/transcripts" }
claude() { print -r -- "$*" }
claude-search
'''

    def test_cycle_case_help_and_reload(self):
        self.wait_for(2, "words> ")
        self.request("change-query(git)")
        self.wait_for(2)
        self.request("trigger(ctrl-i)")
        self.wait_for(0)
        self.request("trigger(ctrl-i)")
        self.wait_for(2)
        self.request("trigger(ctrl-r)")
        self.wait_for(1)
        for mode in ["phrase", "regex"]:
            self.request("trigger(ctrl-s)")
            self.wait_for(1, mode + "> ")
        self.request("change-query(Git (here|elsewhere)$)")
        self.wait_for(1)
        self.request("accept")
        output, _ = self.process.communicate(timeout=5)
        self.assertEqual(output.decode().strip(), "--resume session-here")


if __name__ == "__main__":
    unittest.main()

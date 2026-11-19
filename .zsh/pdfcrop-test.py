"""Check pdfcrop's argument handling without modifying PDFs or loading shell startup files.

Run with: python3 .zsh/pdfcrop-test.py
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


class PdfcropTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (Path(__file__).resolve().parents[1] / '.zshrc').read_text()
        cls.function = re.search(r'^pdfcrop\(\) \{\n.*?^\}', source, re.M | re.S).group()
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        stub = Path(cls.temp.name, 'pdfcpu')
        stub.write_text(
            '#!' + sys.executable + '\n'
            'import json, os, sys\n'
            'print(json.dumps(sys.argv[1:]))\n'
            'sys.exit(int(os.environ.get("PDFCROP_TEST_EXIT", "0")))\n'
        )
        stub.chmod(0o755)
        cls.env = dict(os.environ, PATH=cls.temp.name + os.pathsep + os.environ['PATH'])

    def invoke(self, *args, exit_code=0):
        return subprocess.run(
            ['zsh', '-f', '-c', self.function + '\npdfcrop "$@"', 'pdfcrop-test', *args],
            env=dict(self.env, PDFCROP_TEST_EXIT=str(exit_code)),
            capture_output=True, text=True,
        )

    def forwarded(self, *args):
        result = self.invoke(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_edges_and_pages(self):
        args = self.forwarded('--top', '10', '--right', '20', '--bottom', '30', '--left', '40',
                              '--pages', '1,3-5', 'in.pdf', 'out.pdf')
        self.assertEqual(args, ['crop', '--unit', 'mm', '--pages', '1,3-5', '--',
                                '10 20 30 40', 'in.pdf', 'out.pdf'])

    def test_defaults_and_overrides(self):
        for options, margins in [([], '0 0 0 0'),
                                 (['--all=10', '--left=0'], '10 10 10 0'),
                                 (['--left=0', '--all=10'], '10 10 10 0'),
                                 (['--top', '.5', '--right', '-2'], '.5 -2 0 0')]:
            with self.subTest(options=options):
                self.assertEqual(self.forwarded(*options, 'in', 'out')[-3], margins)

    def test_value_options(self):
        for flag in ['--upw', '--opw', '--upw-file', '--opw-file', '--conf', '-c']:
            for value in ['two words', '-leading-dash', '']:
                with self.subTest(flag=flag, value=value):
                    self.assertEqual(self.forwarded(flag, value, 'in', 'out')[3:5], [flag, value])
            if flag.startswith('--'):
                self.assertEqual(self.forwarded(flag + '=a=b', 'in', 'out')[3:5], [flag, 'a=b'])

    def test_switches(self):
        for flag in ['--force', '--quiet', '--verbose', '--offline', '-q', '-o', '-v', '-vv',
                     '-qovv', '-v2', '--force=false', '--quiet=false', '--offline=true', '--verbose=2']:
            with self.subTest(flag=flag):
                self.assertEqual(self.forwarded(flag, 'in', 'out')[3], flag)

    def test_attached_short_values(self):
        self.assertEqual(self.forwarded('-cdisable', '-p1,3-5', 'in', 'out')[3:7],
                         ['--conf', 'disable', '--pages', '1,3-5'])

    def test_streams_and_quoted_paths(self):
        self.assertEqual(self.forwarded('-', '-')[-2:], ['-', '-'])
        self.assertEqual(self.forwarded('--', '-input file.pdf', 'out $(literal).pdf')[-2:],
                         ['-input file.pdf', 'out $(literal).pdf'])

    def test_reject_invalid_arguments(self):
        for args in [[], ['in'], ['in', 'out', 'extra'], ['--top'], ['--upw-file'],
                     ['--top', '--left', '1', 'in', 'out'], ['--pages=', 'in', 'out'],
                     ['--top=nan', 'in', 'out'], ['--left=1 2', 'in', 'out'],
                     ['--bogus', 'in', 'out'], ['--unit', 'cm', 'in', 'out']]:
            with self.subTest(args=args):
                result = self.invoke(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, '')

    def test_help_and_exit_status(self):
        self.assertIn('--upw', self.invoke('--help').stdout)
        self.assertEqual(self.invoke('in', 'out', exit_code=7).returncode, 7)


if __name__ == '__main__':
    unittest.main()

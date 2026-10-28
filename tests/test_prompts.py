import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import print_rc_i18n as locale

class ConfirmationTests(unittest.TestCase):
    def test_shell_retries_unknown_answers_and_requires_explicit_yes(self):
        script='source "$1/scripts/i18n.sh"; source "$1/scripts/prompts.sh"; prc_confirm "Question?"'
        for language in ('pt-BR','en-US'):
            for answer,expected in [('wrong\n1\n',0),('  SIM  \n',0),('\n',1),('',1),('2\n',1),('n\n',1)]:
                result=subprocess.run(['bash','-c',script,'test',str(ROOT)],input=answer,capture_output=True,text=True,
                                      env={**os.environ,'PRINT_RC_LANG':language})
                self.assertEqual(result.returncode,expected,(language,answer,result.stderr))
                if answer.startswith('wrong'):self.assertIn('1',result.stderr)

    def test_python_confirmation_matches_shell_choices_and_eof(self):
        for language in ('pt-BR','en-US'):
            for answers,expected in [(['typo','1'],True),([' yes '],True),(['2'],False),([''],False),([EOFError()],False)]:
                with patch.dict(os.environ,{'PRINT_RC_LANG':language}),patch('builtins.input',side_effect=answers) as reader:
                    self.assertEqual(locale.confirm('Question?'),expected)
                    self.assertEqual(reader.call_count,len(answers))

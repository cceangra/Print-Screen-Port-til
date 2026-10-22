import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import print_rc_i18n as locale

class LocalizationTests(unittest.TestCase):
    def test_complete_generated_catalogs(self):
        subprocess.run([sys.executable,str(ROOT/'scripts/build/locales.py'),'--check'],check=True)
    def test_locale_precedence_and_aliases(self):
        for env,expected in [({'LC_ALL':'en_US.UTF-8','LC_MESSAGES':'pt_BR.UTF-8'},'en-US'),
                             ({'LC_MESSAGES':'pt_BR.UTF-8','LANG':'en_US.UTF-8'},'pt-BR'),
                             ({'LANG':'pt'},'pt-BR'),({'LANG':'fr_FR.UTF-8'},'en-US'),
                             ({'PRINT_RC_LANG':'en-US','LC_ALL':'pt-BR'},'en-US')]:
            with patch.dict(os.environ,env,clear=True):self.assertEqual(locale.language(),expected)
    def test_saved_override_before_environment(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'config').mkdir();(root/'config/language').write_text('pt-BR\n')
            with patch.object(locale,'ROOT',root),patch.dict(os.environ,{'LC_ALL':'en-US'},clear=True):
                self.assertEqual(locale.language(),'pt-BR')
    def test_shell_treats_substitutions_as_data(self):
        with tempfile.TemporaryDirectory() as temp:
            target=Path(temp)/'MUST_NOT_EXIST'
            value='$(touch '+str(target)+') & `false` %s'
            result=subprocess.check_output(['bash','-c','source "$1/scripts/i18n.sh"; prc_message shell.155 "$2"','test',str(ROOT),value],text=True,env={**os.environ,'PRINT_RC_LANG':'en-US'})
            self.assertIn(value,result);self.assertFalse(target.exists())
    def test_native_help_in_both_languages(self):
        for lang,word in [('en-US','Usage:'),('pt-BR','Uso:')]:
            value=subprocess.check_output([str(ROOT/'bin/print-rc'),'--help'],text=True,env={**os.environ,'PRINT_RC_LANG':lang})
            self.assertIn(word,value)
    def test_helpers_do_not_leave_bytecode_even_when_run_directly(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            shutil.copytree(ROOT/'scripts',root/'scripts',ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copytree(ROOT/'i18n',root/'i18n')
            env=dict(os.environ);env.pop('PYTHONDONTWRITEBYTECODE',None)
            for name in ('atalho.py','atalho_xfce.py','diagnose.py','lifecycle.py','relocate.py'):
                subprocess.run([sys.executable,str(root/'scripts'/name),'--help'],env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            self.assertEqual(list(root.rglob('__pycache__')),[])
    def test_documentation_has_matching_coverage(self):
        en={p.name for p in (ROOT/'docs/en-US').glob('*.md')}
        pt={p.name for p in (ROOT/'docs/pt-BR').glob('*.md')}
        self.assertEqual(en,pt)

if __name__=='__main__':unittest.main()

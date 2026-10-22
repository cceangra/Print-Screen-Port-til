import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

class NativeEntrypointTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'Print RC ç (native)';self.root.mkdir()
        shutil.copy2(ROOT/'Print-RC',self.root/'Print-RC')
        (self.root/'scripts').mkdir();(self.root/'config').mkdir()
        (self.root/'scripts/terminal-action.sh').write_text('exec /bin/bash "$@"\n')
        (self.root/'iniciar.sh').write_text('printf "ARG:%s\\n" "$@";exit 7\n')
    def run_app(self,*args,**extra):
        return subprocess.run([str(self.root/'Print-RC'),*args],capture_output=True,text=True,
                              env={**os.environ,'PRINT_RC_LANG':'en-US',**extra})
    def test_metadata_and_symlink_forward_arguments_without_setup_or_writes(self):
        before=sorted(str(p) for p in self.root.rglob('*'))
        link=Path(self.temp.name)/'public-link';link.symlink_to(self.root/'Print-RC')
        result=subprocess.run([str(link),'--version','literal $(false)'],capture_output=True,text=True)
        self.assertEqual(result.returncode,7);self.assertIn('ARG:literal $(false)',result.stdout)
        self.assertEqual(before,sorted(str(p) for p in self.root.rglob('*')))
        self.assertIn('Usage:',self.run_app('--help').stdout)
    def test_terminal_setup_actions_and_installed_launch(self):
        commands=self.root/'commands';commands.mkdir()
        terminal=commands/'x-terminal-emulator';terminal.write_text('#!/bin/bash\n[[ "$1" == -e ]] || exit 20\nshift\nexec "$@"\n');terminal.chmod(0o755)
        for flag,script in (('--install','instalar.sh'),('--configure','configurar.sh'),
                            ('--shortcut','configurar-tecla.sh'),('--uninstall','desinstalar.sh')):
            (self.root/script).write_text('printf "ACTION:%s\\n" "'+script+'" "$@"\n')
            result=self.run_app(flag,'literal $(false)',DISPLAY=':test',PATH=str(commands))
            self.assertEqual(result.returncode,0,result.stderr);self.assertIn(script,result.stdout)
            self.assertIn('literal $(false)',result.stdout)
        result=self.run_app(DISPLAY=':test',PATH=str(commands))
        self.assertIn('instalar.sh',result.stdout)
        (self.root/'config/opcoes.conf').write_text('installed\n')
        self.assertEqual(self.run_app().returncode,7)
        (self.root/'iniciar.sh').unlink();(self.root/'iniciar.sh').symlink_to('/bin/true')
        self.assertEqual(self.run_app().returncode,2)

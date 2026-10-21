import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import lifecycle
import relocate
import atalho

class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.old=self.root/'old Print RC'
        (self.old/'config').mkdir(parents=True);(self.old/'capturas').mkdir()
        (self.old/'iniciar.sh').write_text('# test launcher\n')
        (self.old/'desinstalar.sh').write_text('# test uninstaller\n')
        (self.old/'.print-rc-installation').write_text('PRINT-RC\n'+str(self.old)+'\n')
        (self.old/'config/opcoes.conf').write_text('save_dir='+str(self.old/'capturas')+'\ncopy_clipboard=0\n')
        self.file=self.root/'desktop/khotkeysrc';self.file.parent.mkdir()
        self.file.write_text('[Data]\nDataCount=0\n\n[UserData]\nKeep=personal\n')
        self.patchers=[patch.object(atalho,'FILE',self.file),patch.object(atalho,'yes',return_value=True),
                       patch.object(atalho,'reload_trinity_shortcuts',return_value=True),
                       patch.dict(os.environ,{'XDG_CURRENT_DESKTOP':'Trinity','XDG_SESSION_TYPE':'x11'})]
        for p in self.patchers:p.start();self.addCleanup(p.stop)
    def prepare(self,shortcut=True):
        if shortcut:self.assertTrue(atalho.install(self.old,self.old/'iniciar.sh',key='Insert'))
        lifecycle.record(self.old)
        entries=[]
        for rel in ('.print-rc-installation','desinstalar.sh','iniciar.sh','config/opcoes.conf',lifecycle.METADATA):
            entries.append(lifecycle.digest(self.old/rel)+'\t'+rel+'\n')
        (self.old/'config/arquivos-instalados.sha256').write_text(''.join(entries))
    def test_setup_is_not_capture_acceptance(self):
        self.prepare(False)
        data=json.loads((self.old/lifecycle.METADATA).read_text())
        self.assertFalse(data['ready']);self.assertFalse(data['capture_verified']);self.assertEqual(data['state'],'FILES_CONFIGURED')
    def test_relocation_updates_only_owned_paths(self):
        self.prepare();new=self.root/'novo ç (Print RC)';self.old.rename(new)
        (new/'capturas/personal.png').write_bytes(b'keep image')
        self.assertTrue(relocate.relocate(new,confirm=lambda:True))
        state=json.loads((new/'config/atalho-state.json').read_text())
        self.assertEqual(state['launcher'],str(new/'iniciar.sh'))
        self.assertIn(atalho.command_for_launcher(new/'iniciar.sh'),self.file.read_text())
        self.assertIn('Keep=personal',self.file.read_text())
        self.assertEqual((new/'capturas/personal.png').read_bytes(),b'keep image')
        self.assertEqual((new/'.print-rc-installation').read_text().splitlines()[1],str(new))
        self.assertIn('save_dir_relative=capturas',(new/'config/opcoes.conf').read_text())
        self.assertTrue(atalho.remove(new));self.assertIn('Keep=personal',self.file.read_text())
    def test_relocation_preserves_changed_external_command(self):
        self.prepare();new=self.root/'moved';self.old.rename(new)
        self.file.write_text(self.file.read_text().replace(atalho.command_for_launcher(self.old/'iniciar.sh'),'user-new-command'))
        before={str(p):p.read_bytes() for p in new.rglob('*') if p.is_file()}
        with self.assertRaises(ValueError):relocate.relocate(new,confirm=lambda:True)
        self.assertEqual(before,{str(p):p.read_bytes() for p in new.rglob('*') if p.is_file()})
        self.assertIn('user-new-command',self.file.read_text())
    def test_interrupted_relocation_retains_removable_journal(self):
        self.prepare();new=self.root/'moved';self.old.rename(new)
        with patch.object(atalho,'write_atomic',side_effect=OSError('injected external write failure')):
            with self.assertRaises(OSError):relocate.relocate(new,confirm=lambda:True)
        state=json.loads((new/'config/atalho-state.json').read_text())
        self.assertEqual(state['status'],'relocating')
        self.assertTrue(atalho.remove(new))
        self.assertNotIn('Name=Print RC',self.file.read_text());self.assertIn('Keep=personal',self.file.read_text())
    def test_remove_preserves_a_concurrent_desktop_change(self):
        self.prepare()
        def concurrent(original):
            self.file.write_text(original+'\n[Concurrent]\nKeep=new-user-setting\n')
            return False
        with patch.object(atalho,'check_unchanged',side_effect=concurrent):
            self.assertFalse(atalho.remove(self.old))
        self.assertIn('Keep=new-user-setting',self.file.read_text())
        self.assertIn('Name=Print RC',self.file.read_text())
        self.assertTrue((self.old/'config/atalho-state.json').exists())
    def test_modified_metadata_is_preserved(self):
        self.prepare(False);path=self.old/lifecycle.METADATA;path.write_text('personal file')
        with self.assertRaises(ValueError):lifecycle.record(self.old)
        self.assertEqual(path.read_text(),'personal file')
    def test_symlink_config_is_never_written(self):
        other=self.root/'outside';other.mkdir();(other/'personal.txt').write_text('keep')
        shutil.rmtree(self.old/'config');(self.old/'config').symlink_to(other,target_is_directory=True)
        with self.assertRaises(ValueError):lifecycle.record(self.old)
        self.assertEqual(list(other.iterdir()),[other/'personal.txt'])

class DiagnosticTests(unittest.TestCase):
    def test_read_only_does_not_execute_binary_or_modify_app(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/'Print RC';root.mkdir();shutil.copy2(ROOT/'diagnosticar.sh',root)
            shutil.copytree(ROOT/'scripts',root/'scripts',ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copytree(ROOT/'i18n',root/'i18n');(root/'bin').mkdir();(root/'config').mkdir()
            sentinel=Path(temp)/'MUST_NOT_EXIST'
            (root/'bin/print-rc').write_text('#!/bin/bash\ntouch '+str(sentinel)+'\n');(root/'bin/print-rc').chmod(0o755)
            (root/'config/opcoes.conf').write_text('save_dir=/home/alice/private-images\ncopy_clipboard=0\n')
            def snapshot():return {str(p.relative_to(root)):(hashlib.sha256(p.read_bytes()).hexdigest(),p.stat().st_mtime_ns) for p in root.rglob('*') if p.is_file()}
            before=snapshot()
            result=subprocess.check_output(['bash',str(root/'diagnosticar.sh'),'--read-only'],text=True)
            value=json.loads(result);self.assertEqual(value['mode'],'READ_ONLY');self.assertEqual(value['overlay_result'],'NOT_RUN')
            self.assertNotIn('alice',result);self.assertFalse(sentinel.exists());self.assertEqual(before,snapshot())
            output=Path(temp)/'explicit-report.json'
            subprocess.run(['bash',str(root/'diagnosticar.sh'),'--output',str(output)],check=True,stdout=subprocess.PIPE)
            saved=output.read_bytes()
            result=subprocess.run(['bash',str(root/'diagnosticar.sh'),'--output',str(output)],capture_output=True)
            self.assertEqual(result.returncode,2);self.assertEqual(output.read_bytes(),saved)
            self.assertEqual(before,snapshot())

if __name__=='__main__':unittest.main()

"""Testa edicao conservadora da configuracao do Trinity sem afetar HOME real."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('atalho', Path(__file__).resolve().parents[1] / 'scripts' / 'atalho.py')
atalho = importlib.util.module_from_spec(spec)
spec.loader.exec_module(atalho)

OLD = '''[Main]\nVersion=2\n\n[Data]\nDataCount=1\n\n[Data_1]\nName=Capturador antigo\nType=SIMPLE_ACTION_DATA\nEnabled=true\n\n[Data_1Actions0]\nCommandURL=ksnapshot\nType=COMMAND_URL\n\n[Data_1Triggers0]\nKey=Print\nType=SHORTCUT\n\n[Misc]\nNaoAlterar=ok\n'''

class ShortcutTests(unittest.TestCase):
    def test_detect_install_remove_and_preserve_other_customization(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            previous=atalho.FILE
            previous_yes=atalho.yes
            previous_desktop=os.environ.get("XDG_CURRENT_DESKTOP")
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                atalho.yes=lambda question: True
                os.environ["XDG_CURRENT_DESKTOP"]="Trinity"
                base=tmp/'app'
                (base/'config').mkdir(parents=True)
                atalho.install(base,base/'iniciar.sh')
                current=atalho.FILE.read_text()
                self.assertEqual(atalho.conflicts(current)[0]['name'],'Print RC')
                self.assertEqual(atalho.get_value(atalho.parse(current)['Data_1Triggers0'],'Key'),'')
                self.assertIn('NaoAlterar=ok',current)
                self.assertEqual((base/'backups/khotkeysrc.antes').read_text(),OLD)
                current=current.replace('NaoAlterar=ok','NaoAlterar=usuario')
                atalho.FILE.write_text(current)
                self.assertTrue(atalho.remove(base))
                final=atalho.FILE.read_text()
                self.assertIn('NaoAlterar=usuario',final)
                self.assertEqual(atalho.get_value(atalho.parse(final)['Data_1Triggers0'],'Key'),'Print')
                self.assertNotIn('Name=Print RC',final)
            finally:
                atalho.FILE=previous
                atalho.yes=previous_yes
                if previous_desktop is None: os.environ.pop("XDG_CURRENT_DESKTOP",None)
                else: os.environ["XDG_CURRENT_DESKTOP"]=previous_desktop

    def test_criado_pelo_app_e_excluido_na_desinstalacao(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            previous=atalho.FILE
            previous_yes=atalho.yes
            previous_desktop=os.environ.get("XDG_CURRENT_DESKTOP")
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.yes=lambda question: True
                os.environ["XDG_CURRENT_DESKTOP"]="Trinity"
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                self.assertTrue(atalho.FILE.is_file())
                self.assertTrue((base/'config/atalho-state.json').is_file())
                self.assertTrue(atalho.remove(base))
                self.assertFalse(atalho.FILE.exists())
                self.assertFalse((base/'config/atalho-state.json').exists())
            finally:
                atalho.FILE=previous
                atalho.yes=previous_yes
                if previous_desktop is None: os.environ.pop("XDG_CURRENT_DESKTOP",None)
                else: os.environ["XDG_CURRENT_DESKTOP"]=previous_desktop

    def test_nao_exclui_arquivo_criado_se_outros_app_usarem(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            previous=atalho.FILE
            previous_yes=atalho.yes
            previous_desktop=os.environ.get("XDG_CURRENT_DESKTOP")
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.yes=lambda question: True
                os.environ["XDG_CURRENT_DESKTOP"]="Trinity"
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                modified=atalho.FILE.read_text()+'\n[OutroApp]\nDado=preservar\n'
                atalho.FILE.write_text(modified)
                self.assertFalse(atalho.remove(base))
                self.assertEqual(atalho.FILE.read_text(),modified)
                self.assertTrue((base/'config/atalho-state.json').exists())
                self.assertTrue((base/'backups/khotkeysrc.antes').exists())
            finally:
                atalho.FILE=previous
                atalho.yes=previous_yes
                if previous_desktop is None: os.environ.pop("XDG_CURRENT_DESKTOP",None)
                else: os.environ["XDG_CURRENT_DESKTOP"]=previous_desktop

    def test_nao_cria_diretorios_externos_ausentes(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            previous=atalho.FILE
            previous_yes=atalho.yes
            previous_desktop=os.environ.get("XDG_CURRENT_DESKTOP")
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.yes=lambda question: True
                os.environ["XDG_CURRENT_DESKTOP"]="Trinity"
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                self.assertFalse(atalho.FILE.parent.exists())
                self.assertFalse((base/'config/atalho-state.json').exists())
            finally:
                atalho.FILE=previous
                atalho.yes=previous_yes
                if previous_desktop is None: os.environ.pop("XDG_CURRENT_DESKTOP",None)
                else: os.environ["XDG_CURRENT_DESKTOP"]=previous_desktop

    def test_no_conflict(self):
        self.assertEqual(atalho.conflicts('[Data_1Triggers0]\nKey=Shift+Print\n'),[])
        self.assertEqual(len(atalho.conflicts('[Data_1Triggers0]\nKey=Print\n')),1)

if __name__=='__main__':
    unittest.main()

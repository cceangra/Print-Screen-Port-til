"""Regressao do formato REAL KHotKeys do Q4OS/Trinity e do reparo legado.
Isolado: usa somente arquivos temporarios, nunca o HOME real.
"""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1]/'scripts/atalho.py'
spec = importlib.util.spec_from_file_location('atalho_trinity_compat',path)
hotkeys = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hotkeys)

# Formato de grupo/acao/gatilho informado pelo Trinity REAL do usuario.
MICROPHONE = (
    '[Data]\nDataCount=3\n\n'
    '[Data_1]\nName=Examples\nEnabled=false\nType=ACTION_DATA_GROUP\n\n'
    '[Data_2]\nName=Konqueror Gestures\nEnabled=true\nType=ACTION_DATA_GROUP\n\n'
    '[Data_3]\nName=Mutar Microfone\nEnabled=true\n'
    'Type=COMMAND_URL_SHORTCUT_ACTION_DATA\n\n'
    '[Data_3Actions0]\nCommandURL=comando-do-microfone\nType=COMMAND_URL\n\n'
    '[Data_3Triggers0]\nKey=Win+M\nType=SHORTCUT\n\n'
    '[OutroGrupo]\nUsuario=nao-alterar\n\n'
)

class TrinityFormatTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root=Path(self.tmp.name)
        self.base=root/'Print RC com espacos'
        (self.base/'config').mkdir(parents=True)
        self.launcher=self.base/'iniciar.sh'
        self.file=root/'.trinity/share/config/khotkeysrc'
        self.file.parent.mkdir(parents=True)
        self.file.write_text(MICROPHONE,encoding='utf-8')
        self.pfile=patch.object(hotkeys,'FILE',self.file)
        self.py=patch.object(hotkeys,'yes',return_value=True)
        self.preload=patch.object(hotkeys,'reload_trinity_shortcuts',return_value=True)
        self.desktop=patch.dict(os.environ,{'XDG_CURRENT_DESKTOP':'Trinity'})
        for p in (self.pfile,self.py,self.preload,self.desktop):
            p.start()
            self.addCleanup(p.stop)

    def install(self):
        self.assertTrue(hotkeys.install(self.base,self.launcher,key='Print'))
        state=json.loads((self.base/'config/atalho-state.json').read_text())
        return state

    def test_um_unico_sim_substitui_print_de_outro_app_e_restauracao(self):
        # Simula pessoa confirmando somente UMA vez o uso da tecla.
        old=MICROPHONE.replace('Key=Win+M','Key=Print')
        self.file.write_text(old,encoding='utf-8')
        with patch.object(hotkeys,'yes',return_value=True) as confirm:
            state=self.install()
        self.assertEqual(confirm.call_count,1)
        data=hotkeys.parse(self.file.read_text())
        self.assertEqual(hotkeys.get_value(data['Data_3Triggers0'],'Key'),'')
        self.assertEqual(hotkeys.get_value(data['Data_3Actions0'],'CommandURL'),
                         'comando-do-microfone')
        self.assertEqual(hotkeys.get_value(data[state['group']+'Triggers0'],'Key'),'Print')
        self.assertTrue(hotkeys.remove(self.base))
        restored=hotkeys.parse(self.file.read_text())
        self.assertEqual(hotkeys.get_value(restored['Data_3Triggers0'],'Key'),'Print')
        self.assertNotIn('Name=Print RC',self.file.read_text())

    def test_sem_confirmar_nao_troca_atalho_original(self):
        original=MICROPHONE.replace('Key=Win+M','Key=Print')
        self.file.write_text(original,encoding='utf-8')
        with patch.object(hotkeys,'yes',return_value=False) as confirm:
            self.assertFalse(hotkeys.install(self.base,self.launcher,key='Print'))
        self.assertEqual(confirm.call_count,1)
        self.assertEqual(self.file.read_text(),original)
        self.assertFalse((self.base/'config/atalho-state.json').exists())

    def test_nova_instalacao_usa_tipo_suportado_pelo_trinity(self):
        s=self.install()
        groups=hotkeys.parse(self.file.read_text())
        self.assertEqual(hotkeys.get_value(groups[s['group']],'Type'),
                         'COMMAND_URL_SHORTCUT_ACTION_DATA')
        self.assertEqual(hotkeys.get_value(groups[s['group']+'Actions0'],'Type'),
                         'COMMAND_URL')
        self.assertEqual(hotkeys.get_value(groups[s['group']+'Triggers0'],'Type'),
                         'SHORTCUT')
        self.assertEqual(hotkeys.get_value(groups[s['group']+'Triggers0'],'Key'),'Print')
        self.assertEqual(hotkeys.get_value(groups['Data_3'],'Name'),'Mutar Microfone')
        self.assertEqual(hotkeys.get_value(groups['Data_3Triggers0'],'Key'),'Win+M')
        self.assertIn('[OutroGrupo]\nUsuario=nao-alterar',self.file.read_text())

    def test_reparar_instalacao_048_sem_mudar_backup_ou_atalhos_alheios(self):
        s=self.install()
        original_backup=(self.base/'backups/khotkeysrc.antes').read_bytes()
        before=self.file.read_text()
        original_group=hotkeys.parse(before)[s['group']]
        legacy=hotkeys.replace_block(
            before,s['group'],hotkeys.set_value(original_group,'Type','SIMPLE_ACTION_DATA')
        )
        self.file.write_text(legacy)
        self.assertTrue(hotkeys.repair(self.base,self.launcher))
        repaired=self.file.read_text()
        self.assertNotIn('Type=SIMPLE_ACTION_DATA',repaired)
        self.assertIn('[Data_3]\nName=Mutar Microfone\nEnabled=true\nType=COMMAND_URL_SHORTCUT_ACTION_DATA',
                      repaired)
        self.assertIn('[OutroGrupo]\nUsuario=nao-alterar',repaired)
        self.assertEqual((self.base/'backups/khotkeysrc.antes').read_bytes(),original_backup)
        self.assertTrue(hotkeys.repair(self.base,self.launcher))
        self.assertEqual(self.file.read_text(),repaired)
        # Reparar nao pode impossibilitar remover o atalho pela desinstalacao.
        self.assertTrue(hotkeys.remove(self.base))
        self.assertEqual(self.file.read_text().count('Name=Print RC'),0)
        self.assertIn('Name=Mutar Microfone',self.file.read_text())
        self.assertIn('Key=Win+M',self.file.read_text())

    def test_reparo_automatico_via_instalador_quando_estado_ja_existe(self):
        s=self.install()
        current=self.file.read_text()
        block=hotkeys.parse(current)[s['group']]
        self.file.write_text(hotkeys.replace_block(
            current,s['group'],hotkeys.set_value(block,'Type','SIMPLE_ACTION_DATA')
        ))
        self.assertTrue(hotkeys.install(self.base,self.launcher))
        self.assertEqual(hotkeys.get_value(hotkeys.parse(self.file.read_text())[s['group']],'Type'),
                         'COMMAND_URL_SHORTCUT_ACTION_DATA')
        self.assertEqual(len([k for k in hotkeys.parse(self.file.read_text())
                              if hotkeys.get_value(hotkeys.parse(self.file.read_text())[k],'Name')
                                 =='Print RC']),1)

    def test_nao_alterar_outro_atalho_ou_chave_modificada(self):
        s=self.install()
        before=self.file.read_text()
        trigger=s['group']+'Triggers0'
        changed=hotkeys.replace_block(before,trigger,
                                      hotkeys.set_value(hotkeys.parse(before)[trigger],
                                                        'Key','Ctrl+Alt+M'))
        self.file.write_text(changed)
        self.assertFalse(hotkeys.repair(self.base,self.launcher))
        self.assertEqual(self.file.read_text(),changed)

    def test_sem_aceite_nao_reparar(self):
        s=self.install()
        before=self.file.read_text()
        self.file.write_text(hotkeys.replace_block(
            before,s['group'],
            hotkeys.set_value(hotkeys.parse(before)[s['group']],
                              'Type','SIMPLE_ACTION_DATA')
        ))
        old=self.file.read_text()
        with patch.object(hotkeys,'yes',return_value=False):
            self.assertFalse(hotkeys.repair(self.base,self.launcher))
        self.assertEqual(self.file.read_text(),old)

if __name__=='__main__':
    unittest.main()

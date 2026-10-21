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
    def test_trinity_grava_tecla_x11_detectada_sys_req_e_restauracao(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes=atalho.FILE,atalho.yes
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                atalho.yes=lambda question: True
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh',key='Sys_Req')
                import json
                state=json.loads((base/'config/atalho-state.json').read_text())
                own=atalho.parse(atalho.FILE.read_text())[state['group']+'Triggers0']
                self.assertEqual(atalho.get_value(own,'Key'),'Sys_Req')
                self.assertEqual(state['key'],'Sys_Req')
                self.assertTrue(atalho.remove(base))
                self.assertEqual(atalho.FILE.read_text().split('Key=Print').__len__(),2)
            finally:
                atalho.FILE,atalho.yes=old_file,old_yes
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_trinity_recusa_nomes_de_teclas_invalidos_sem_modificar(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file=atalho.FILE
            try:
                atalho.FILE=tmp/'khotkeysrc'
                for key in ('../../etc/passwd','Escape','Control_L','F12\\nName=Injetado'):
                    with self.assertRaises(ValueError):
                        atalho.install(tmp,tmp/'iniciar.sh',key=key)
                self.assertFalse(atalho.FILE.exists())
                self.assertTrue(atalho.valid_key('F12'))
            finally:
                atalho.FILE=old_file


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

    def test_nao_sobrescreve_alteracao_de_outro_app_durante_perguntas(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes=atalho.FILE,atalho.yes
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                def answer(question):
                    if 'Registrar a tecla Print' in question:
                        atalho.FILE.write_text(OLD.replace('NaoAlterar=ok','NaoAlterar=outro-app'))
                    return True
                atalho.yes=answer
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                self.assertEqual(atalho.FILE.read_text(),OLD.replace('NaoAlterar=ok','NaoAlterar=outro-app'))
                self.assertFalse((base/'config/atalho-state.json').exists())
            finally:
                atalho.FILE,atalho.yes=old_file,old_yes
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_corrida_no_momento_da_escrita_nao_deixa_backup_travando_instalacao(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes,old_check=atalho.FILE,atalho.yes,atalho.check_unchanged
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                atalho.yes=lambda question: True
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                counter=[0]
                def check(original):
                    counter[0]+=1
                    if counter[0]==2:
                        atalho.FILE.write_text(OLD.replace('NaoAlterar=ok','NaoAlterar=edicao-concorrente'))
                    return old_check(original)
                atalho.check_unchanged=check
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                self.assertGreaterEqual(counter[0],2)
                self.assertEqual(atalho.FILE.read_text(),OLD.replace('NaoAlterar=ok','NaoAlterar=edicao-concorrente'))
                self.assertFalse((base/'config/atalho-state.json').exists())
                self.assertFalse((base/'backups/khotkeysrc.antes').exists())
            finally:
                atalho.FILE,atalho.yes,atalho.check_unchanged=old_file,old_yes,old_check
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_nao_remove_secoes_parecidas_criadas_por_terceiros(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes=atalho.FILE,atalho.yes
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                atalho.yes=lambda question: True
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                import json
                state=json.loads((base/'config/atalho-state.json').read_text())
                foreign=f"[{state['group']}ActionsPersonal]\nDado=nao-remover\n"
                with atalho.FILE.open('a') as append:
                    append.write(foreign)
                self.assertTrue(atalho.remove(base))
                final=atalho.FILE.read_text()
                self.assertIn(foreign,final)
                self.assertIn('Name=Capturador antigo',final)
                self.assertNotIn('Name=Print RC',final)
            finally:
                atalho.FILE,atalho.yes=old_file,old_yes
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_nao_reutiliza_indice_residual_de_atalho(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes=atalho.FILE,atalho.yes
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD+'\n[Data_2Triggers0]\nKey=Ctrl+F11\n')
                atalho.yes=lambda question: True
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                base=tmp/'app'
                atalho.install(base,base/'iniciar.sh')
                import json
                state=json.loads((base/'config/atalho-state.json').read_text())
                self.assertEqual(state['group'],'Data_3')
                self.assertIn('[Data_2Triggers0]',atalho.FILE.read_text())
            finally:
                atalho.FILE,atalho.yes=old_file,old_yes
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_comando_funciona_com_espacos_sem_permissao_executavel(self):
        import shlex
        import subprocess
        with tempfile.TemporaryDirectory() as temporary:
            base=Path(temporary)/'pasta com espacos/Print RC'
            base.mkdir(parents=True)
            script=base/'iniciar.sh'
            script.write_text('#!/bin/bash\necho TESTE-ATALHO-OK\n',encoding='utf-8')
            script.chmod(0o644)
            self.assertFalse(os.access(script,os.X_OK))
            command=atalho.command_for_launcher(script)
            self.assertEqual(
                shlex.split(command), ['/bin/bash',str(script)]
            )
            result=subprocess.run(shlex.split(command),capture_output=True,text=True,check=True)
            self.assertIn('TESTE-ATALHO-OK',result.stdout)

    def test_reparar_atribuicao_antiga_preserva_atalhos_e_backup(self):
        import json
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes=atalho.FILE,atalho.yes
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                atalho.yes=lambda question: True
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                base=tmp/'pasta com espacos/app'
                command=base/'iniciar.sh'
                with patch.object(atalho,'reload_trinity_shortcuts',return_value=True):
                    atalho.install(base,command)
                    state=json.loads((base/'config/atalho-state.json').read_text())
                    section=state['group']+'Actions0'
                    content=atalho.FILE.read_text()
                    block=atalho.parse(content)[section]
                    original_command=atalho.legacy_command_for_launcher(command)
                    current_command=atalho.command_for_launcher(command)
                    self.assertIn(current_command,block)
                    content=atalho.replace_block(
                        content,section,atalho.set_value(block,'CommandURL',original_command)
                    )
                    atalho.FILE.write_text(content)
                    backup=(base/'backups/khotkeysrc.antes').read_text()
                    self.assertTrue(atalho.repair(base,command))
                    latest=atalho.FILE.read_text()
                    self.assertIn('CommandURL='+current_command,latest)
                    self.assertIn('NaoAlterar=ok',latest)
                    self.assertEqual((base/'backups/khotkeysrc.antes').read_text(),backup)
                    self.assertEqual(json.loads((base/'config/atalho-state.json').read_text()),state)
                    self.assertTrue(atalho.remove(base))
                    self.assertEqual(atalho.get_value(
                        atalho.parse(atalho.FILE.read_text())['Data_1Triggers0'],'Key'
                    ),'Print')
            finally:
                atalho.FILE,atalho.yes=old_file,old_yes
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_reparo_recusa_comando_modificado_por_terceiros(self):
        from unittest.mock import patch
        import json
        with tempfile.TemporaryDirectory() as temporary:
            tmp=Path(temporary)
            old_file,old_yes=atalho.FILE,atalho.yes
            old_desktop=os.environ.get('XDG_CURRENT_DESKTOP')
            try:
                atalho.FILE=tmp/'home/.trinity/share/config/khotkeysrc'
                atalho.FILE.parent.mkdir(parents=True)
                atalho.FILE.write_text(OLD)
                atalho.yes=lambda question: True
                os.environ['XDG_CURRENT_DESKTOP']='Trinity'
                base=tmp/'app'
                with patch.object(atalho,'reload_trinity_shortcuts',return_value=True):
                    atalho.install(base,base/'iniciar.sh')
                    state=json.loads((base/'config/atalho-state.json').read_text())
                    key=state['group']+'Actions0'
                    data=atalho.FILE.read_text()
                    block=atalho.parse(data)[key]
                    altered=atalho.replace_block(data,key,atalho.set_value(block,'CommandURL','app-de-outra-pessoa'))
                    atalho.FILE.write_text(altered)
                    self.assertFalse(atalho.repair(base,base/'iniciar.sh'))
                    self.assertEqual(atalho.FILE.read_text(),altered)
            finally:
                atalho.FILE,atalho.yes=old_file,old_yes
                if old_desktop is None: os.environ.pop('XDG_CURRENT_DESKTOP',None)
                else: os.environ['XDG_CURRENT_DESKTOP']=old_desktop

    def test_reload_dcop_nao_reinicia_nem_encerra_trinity(self):
        from unittest.mock import patch,Mock
        with patch.object(atalho.shutil,'which',return_value='/usr/bin/dcop'), \
             patch.object(atalho.subprocess,'run',return_value=Mock(returncode=0,stdout='',stderr='')) as call:
            self.assertTrue(atalho.reload_trinity_shortcuts())
            args,kwargs=call.call_args
            self.assertEqual(
                args[0],
                ['/usr/bin/dcop','kded','khotkeysd','reread_configuration']
            )
            self.assertEqual(kwargs['timeout'],5)

    def test_no_conflict(self):
        self.assertEqual(atalho.conflicts('[Data_1Triggers0]\nKey=Shift+Print\n'),[])
        self.assertEqual(len(atalho.conflicts('[Data_1Triggers0]\nKey=Print\n')),1)

if __name__=='__main__':
    unittest.main()

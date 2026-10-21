"""Testes da integracao XFCE, inteiramente simulados; nao altera desktop do usuario."""
import importlib.util
import os
from pathlib import Path
import shlex
import tempfile
import unittest
from unittest.mock import patch, Mock

module_path = Path(__file__).resolve().parents[1] / 'scripts/atalho_xfce.py'
spec = importlib.util.spec_from_file_location('atalho_xfce', module_path)
xfce = importlib.util.module_from_spec(spec)
spec.loader.exec_module(xfce)

class ShortcutXfceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name) / 'Print RC com espacos'
        (self.base / 'config').mkdir(parents=True)
        self.launcher = self.base / 'iniciar.sh'
        self.data = {xfce.DEFAULT: 'xfce4-screenshooter'}

    def fake_get(self, key=xfce.PROPERTY):
        return self.data.get(key)

    def fake_set(self, command, existed, prop=xfce.PROPERTY):
        self.assertEqual(existed, prop in self.data)
        self.data[prop] = command

    def fake_remove(self, prop=xfce.PROPERTY):
        self.data.pop(prop, None)

    def scope(self, yes=True):
        from contextlib import ExitStack
        stack = ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(patch.object(xfce, 'check_environment'))
        stack.enter_context(patch.object(xfce, 'get', side_effect=self.fake_get))
        stack.enter_context(patch.object(xfce, 'set_key', side_effect=self.fake_set))
        stack.enter_context(patch.object(xfce, 'remove_key', side_effect=self.fake_remove))
        stack.enter_context(patch.object(xfce, 'yes', return_value=yes))
        return stack

    def test_tecla_fisica_insert_configura_insert_nao_print(self):
        # Reproduz o desktop Xfce mostrado pelo usuario:
        # a tecla com rotulo Print e recebida pelo X11 como Insert.
        self.scope()
        insert='/commands/custom/Insert'
        self.data[insert]='programa-de-terceiros'
        self.data[xfce.PROPERTY]='xfce4-screenshooter'
        with patch.object(xfce,'yes',return_value=True) as confirm:
            self.assertTrue(xfce.install(self.base,self.launcher,key='Insert'))
        self.assertEqual(confirm.call_count,1)
        self.assertEqual(self.data[insert],xfce.app_command(self.launcher))
        self.assertEqual(self.data[xfce.PROPERTY],'xfce4-screenshooter')
        import json
        state=json.loads((self.base/xfce.STATE_FILE).read_text())
        self.assertEqual(state['key'],'Insert')
        self.assertEqual(state['property'],insert)
        self.assertTrue(xfce.remove(self.base))
        self.assertEqual(self.data[insert],'programa-de-terceiros')
        self.assertEqual(self.data[xfce.PROPERTY],'xfce4-screenshooter')

    def test_instalacao_de_insert_sem_atalho_anterior(self):
        self.scope()
        self.assertTrue(xfce.install(self.base,self.launcher,key='Insert'))
        self.assertEqual(self.data['/commands/custom/Insert'],xfce.app_command(self.launcher))
        self.assertTrue(xfce.remove(self.base))
        self.assertNotIn('/commands/custom/Insert',self.data)

    def test_uma_confirmacao_substitui_custom_print_e_restauracao(self):
        self.scope()
        self.data[xfce.PROPERTY] = 'xfce4-screenshooter -f'
        with patch.object(xfce, 'yes', return_value=True) as confirm:
            self.assertTrue(xfce.install(self.base, self.launcher))
        self.assertEqual(confirm.call_count, 1)
        self.assertEqual(self.data[xfce.PROPERTY],xfce.app_command(self.launcher))
        self.assertTrue(xfce.remove(self.base))
        self.assertEqual(self.data[xfce.PROPERTY], 'xfce4-screenshooter -f')

    def test_criar_atualizar_e_restaurar_atalho_anterior(self):
        self.scope()
        self.data[xfce.PROPERTY] = 'xfce4-screenshooter -f'
        self.assertTrue(xfce.install(self.base, self.launcher))
        expected = '/bin/bash ' + shlex.quote(str(self.launcher))
        self.assertEqual(shlex.split(expected), ['/bin/bash', str(self.launcher)])
        self.assertEqual(self.data[xfce.PROPERTY], expected)
        self.assertEqual((self.base/xfce.STATE_FILE).stat().st_mode & 0o777, 0o600)
        self.assertTrue(xfce.install(self.base, self.launcher))
        self.assertTrue(xfce.remove(self.base))
        self.assertEqual(self.data[xfce.PROPERTY], 'xfce4-screenshooter -f')
        self.assertFalse((self.base/xfce.STATE_FILE).exists())

    def test_nova_tecla_deixa_padrão_original_intacto(self):
        self.scope()
        self.assertTrue(xfce.install(self.base, self.launcher))
        self.assertIn(xfce.PROPERTY,self.data)
        self.assertEqual(self.data[xfce.DEFAULT], 'xfce4-screenshooter')
        self.assertTrue(xfce.remove(self.base))
        self.assertNotIn(xfce.PROPERTY, self.data)
        self.assertEqual(self.data[xfce.DEFAULT], 'xfce4-screenshooter')

    def test_cancelamento_nada_altera(self):
        self.scope(yes=False)
        self.assertFalse(xfce.install(self.base, self.launcher))
        self.assertNotIn(xfce.PROPERTY, self.data)
        self.assertFalse((self.base/xfce.STATE_FILE).exists())

    def test_nao_roubar_registro_preexistente_identico(self):
        self.scope()
        self.data[xfce.PROPERTY] = xfce.app_command(self.launcher)
        self.assertFalse(xfce.install(self.base, self.launcher))
        self.assertFalse((self.base/xfce.STATE_FILE).exists())

    def test_terceiro_mudou_atalho_apos_instalar(self):
        self.scope()
        self.assertTrue(xfce.install(self.base, self.launcher))
        self.data[xfce.PROPERTY] = 'meu-programa'
        self.assertFalse(xfce.remove(self.base))
        self.assertEqual(self.data[xfce.PROPERTY], 'meu-programa')
        self.assertTrue((self.base/xfce.STATE_FILE).exists())

    def test_instalacao_interrompida_antes_de_alterar_atalho(self):
        self.scope()
        def fail(command, existed):
            raise RuntimeError('simulado')
        with patch.object(xfce, 'set_key', side_effect=fail):
            self.assertFalse(xfce.install(self.base, self.launcher))
        self.assertTrue((self.base/xfce.STATE_FILE).exists())
        self.assertTrue(xfce.remove(self.base))
        self.assertFalse((self.base/xfce.STATE_FILE).exists())

    def test_estado_simbolico_recusado(self):
        self.scope()
        target=Path(self.temp.name)/'pessoal.txt'
        target.write_text('dados privados',encoding='utf-8')
        (self.base/xfce.STATE_FILE).symlink_to(target)
        with self.assertRaises(RuntimeError):
            xfce.install(self.base, self.launcher)
        self.assertEqual(target.read_text(),'dados privados')

    def test_leitura_lista_distingue_ausente_e_falha_sem_traducao(self):
        def simulated(args, **kwargs):
            if '-l' in args:
                return Mock(returncode=0,stdout=xfce.PROPERTY+'\n',stderr='')
            return Mock(returncode=0,stdout='comando antigo\n',stderr='')
        with patch.object(xfce.shutil,'which',return_value='/usr/bin/xfconf-query'):
            with patch.object(xfce.subprocess,'run',side_effect=simulated) as runner:
                self.assertEqual(xfce.get(), 'comando antigo')
                self.assertIsNone(xfce.get('/commands/custom/NAO_EXISTE'))
                self.assertIn('-l',runner.call_args_list[-1].args[0])

    def test_detecta_exclusivamente_xfce(self):
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'XFCE','XDG_SESSION_TYPE':'x11'}):
            self.assertTrue(xfce.desktop_is_xfce())
        with patch.dict(os.environ, {'XDG_CURRENT_DESKTOP':'Trinity','XDG_SESSION_TYPE':'x11'}):
            self.assertFalse(xfce.desktop_is_xfce())

if __name__ == '__main__':
    unittest.main()

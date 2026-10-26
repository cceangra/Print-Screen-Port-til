import os
from pathlib import Path
import shutil
import configparser
import shlex
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

class NativeEntrypointTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'Print RC ç (native)';self.root.mkdir()
        shutil.copy2(ROOT/'Print-RC',self.root/'Print-RC')
        shutil.copy2(ROOT/'Instalar',self.root/'Instalar')
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

    def test_installer_remains_clickable_after_configuration_and_renaming(self):
        (self.root/'config/opcoes.conf').write_text('already configured\n')
        (self.root/'instalar.sh').write_text('printf "INSTALL:%s\\n" "$@"\n')
        commands=self.root/'commands';commands.mkdir()
        terminal=commands/'sakura'
        terminal.write_text('#!/bin/bash\n[[ "$1" == -x && "$#" == 2 ]] || exit 20\nexec /bin/bash -c "$2"\n')
        terminal.chmod(0o755)
        installer=self.root/'Instalar';renamed=self.root/'Install again';installer.rename(renamed)
        result=subprocess.run([str(renamed),'literal $(false)'],capture_output=True,text=True,
                              env={**os.environ,'DISPLAY':':test','PATH':str(commands)})
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('INSTALL:literal $(false)',result.stdout)
        (commands/'x-terminal-emulator').symlink_to(terminal)
        result=subprocess.run([str(renamed),'literal $(false)'],capture_output=True,text=True,
                              env={**os.environ,'DISPLAY':':test','PATH':str(commands)})
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('INSTALL:literal $(false)',result.stdout)
        result=subprocess.run([str(renamed),'--version'],capture_output=True,text=True)
        self.assertEqual(result.returncode,7)
        self.assertIn('ARG:--version',result.stdout)

    def test_missing_terminal_has_visible_error_without_writing_app_files(self):
        (self.root/'instalar.sh').write_text('exit 0\n')
        commands=self.root/'commands';commands.mkdir()
        dialog=commands/'zenity'
        dialog.write_text('#!/bin/bash\nprintf "DIALOG:%s\\n" "$@"\n')
        dialog.chmod(0o755)
        before=sorted(str(p) for p in self.root.rglob('*'))
        result=self.run_app('--install',DISPLAY=':test',PATH=str(commands))
        self.assertEqual(result.returncode,2)
        self.assertIn('No terminal could be opened',result.stdout)
        self.assertEqual(before,sorted(str(p) for p in self.root.rglob('*')))

    def test_desktop_installer_accepts_file_paths_and_uris_without_shell_interpolation(self):
        shutil.copytree(ROOT/'scripts',self.root/'scripts',dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copytree(ROOT/'i18n',self.root/'i18n')
        # Keep this fixture noninteractive; real terminal argv is tested separately.
        (self.root/'scripts/terminal-action.sh').write_text('exec /bin/bash "$@"\n')
        commands=self.root/'commands';commands.mkdir()
        terminal=commands/'x-terminal-emulator';terminal.write_text('#!/bin/bash\nshift\nexec "$@"\n');terminal.chmod(0o755)
        launcher=self.root/'Instalar.desktop';shutil.copy2(ROOT/'Instalar.desktop',launcher)
        (self.root/'instalar.sh').write_text('printf "DESKTOP-INSTALL\\n"\n')
        config=configparser.ConfigParser(interpolation=None);config.read(launcher)
        command=shlex.split(config['Desktop Entry']['Exec'])
        self.assertEqual(command[-1],'%k')
        for location in (str(launcher),launcher.as_uri()):
            (self.root/'Instalar').chmod(0o644)
            result=subprocess.run([*command[:-1],location],cwd='/',capture_output=True,text=True,
                                  env={**os.environ,'DISPLAY':':test','PATH':str(commands)+':'+os.environ['PATH']})
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('DESKTOP-INSTALL',result.stdout)
            self.assertTrue((self.root/'Instalar').stat().st_mode & 0o100)
        outside=Path(self.temp.name)/'outside';outside.write_text('personal file');outside.chmod(0o644)
        (self.root/'Instalar').unlink();(self.root/'Instalar').symlink_to(outside)
        result=subprocess.run([sys.executable,*command[1:-1],str(launcher)],cwd='/',capture_output=True,text=True,
                              env={**os.environ,'DISPLAY':'','WAYLAND_DISPLAY':'','PATH':str(commands)})
        self.assertEqual(result.returncode,2)
        self.assertEqual(outside.stat().st_mode & 0o777,0o644)
        self.assertEqual(outside.read_text(),'personal file')

    def test_early_shell_failure_from_graphical_launch_is_visible(self):
        shutil.copy2(ROOT/'iniciar.sh',self.root/'iniciar.sh')
        shutil.copytree(ROOT/'scripts',self.root/'scripts',dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copytree(ROOT/'i18n',self.root/'i18n')
        commands=self.root/'commands';commands.mkdir()
        dialog=commands/'zenity';dialog.write_text('#!/bin/bash\nprintf "DIALOG:%s\\n" "$@"\n');dialog.chmod(0o755)
        (self.root/'config/opcoes.conf').write_text('already configured\n')
        # A package can fail before reaching the supervisor (e.g. missing launcher).
        result=self.run_app(DISPLAY=':test',XDG_SESSION_TYPE='x11',PATH=str(commands)+':'+os.environ['PATH'])
        self.assertNotEqual(result.returncode,0)
        self.assertIn('DIALOG:',result.stdout)

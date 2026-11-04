import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
spec=importlib.util.spec_from_file_location('complete_setup',ROOT/'scripts/complete_setup.py')
setup=importlib.util.module_from_spec(spec);spec.loader.exec_module(setup)

class CompleteSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name)/'Fontes ç (teste)';self.base.mkdir()
        (self.base/'personal.png').write_bytes(b'personal image')
        self.source='a'*40;self.prefix='https://github.com/'+setup.REPOSITORY+'/releases/download/candidate-'+self.source+'/'
        binaries=[];self.files={}
        for name in setup.BINARIES:
            data=(ROOT/name).read_bytes();self.files[name]=data
            binaries.append({'path':name,'sha256':hashlib.sha256(data).hexdigest(),
                'interpreter':'/lib64/ld-linux-x86-64.so.2','needed':['libc.so.6'],
                'symbol_requirements':{'GLIBC':'2.31','GLIBCXX':'3.4.28'}})
        self.files.update({name:b'fixture' for name in ('Instalar.desktop','Configurar.desktop','instalar.sh',
            'iniciar.sh','scripts/desktop_install.py','src/main.cpp','LICENSE')})
        manifest={'git_commit':self.source,'source_dirty':False,'architecture':'x86_64','libc_family':'glibc',
                  'backend':'x11','binaries':binaries}
        self.files['build-manifest.json']=json.dumps(manifest).encode()
        self.files['package-files.json']=json.dumps({'schema':1,'files':{
            name:hashlib.sha256(data).hexdigest() for name,data in self.files.items()}}).encode()
        self.archive=self.make_archive()
        self.responses={setup.API:json.dumps([{'tag_name':'candidate-'+self.source,'draft':False,'prerelease':True,
            'assets':[{'name':name,'browser_download_url':self.prefix+name} for name in
                      (setup.ARCHIVE,setup.ARCHIVE+'.sha256','build-manifest.json')]}]).encode()}
        self.refresh_download()
        self.platform=mock.patch.object(setup,'platform_check');self.platform.start();self.addCleanup(self.platform.stop)
        self.http=mock.patch.object(setup,'read_url',side_effect=lambda url,limit:self.responses[url]);self.http.start();self.addCleanup(self.http.stop)
    def make_archive(self,extra=None):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w',compression=zipfile.ZIP_DEFLATED) as archive:
            for name,data in self.files.items():
                info=zipfile.ZipInfo('Print-RC/'+name)
                info.external_attr=(stat.S_IFREG|(0o755 if name in setup.BINARIES or name.endswith(('.sh','.desktop')) else 0o644))<<16
                archive.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED)
            if extra:archive.writestr(extra,b'unsafe')
        return stream.getvalue()
    def refresh_download(self):
        self.responses[self.prefix+setup.ARCHIVE]=self.archive
        self.responses[self.prefix+setup.ARCHIVE+'.sha256']=(hashlib.sha256(self.archive).hexdigest()+'  '+setup.ARCHIVE+'\n').encode()
    def assert_preserved(self):
        self.assertEqual((self.base/'personal.png').read_bytes(),b'personal image')
        self.assertFalse((self.base/'config').exists())
        self.assertEqual(list(self.base.glob('.print-rc-download-*')),[])
    def test_decline_never_accesses_network_or_writes(self):
        self.assertIsNone(setup.prepare(self.base,lambda message:False))
        setup.read_url.assert_not_called();self.assert_preserved()
        self.assertEqual([p.name for p in self.base.iterdir()],['personal.png'])
    def test_download_complete_verified_package_and_retry_without_network(self):
        target=setup.prepare(self.base,lambda message:True)
        self.assertEqual(target,self.base/'Print-RC');self.assert_preserved()
        for name in setup.BINARIES:
            self.assertEqual((target/name).read_bytes(),self.files[name])
            self.assertTrue(os.access(target/name,os.X_OK))
        (target/'config').mkdir();(target/'config/language').write_text('pt-BR\n')
        setup.read_url.reset_mock()
        self.assertIsNone(setup.prepare(self.base,lambda message:False))
        self.assertEqual(setup.prepare(self.base,lambda message:True),target)
        setup.read_url.assert_not_called()
        self.assertEqual((target/'config/language').read_text(),'pt-BR\n')
    def test_checksum_failure_leaves_no_app_or_partial_files(self):
        self.responses[self.prefix+setup.ARCHIVE]=b'corrupted'
        with self.assertRaises(ValueError):setup.prepare(self.base,lambda message:True)
        self.assertFalse((self.base/'Print-RC').exists());self.assert_preserved()
    def test_traversal_rejected_before_extraction(self):
        self.archive=self.make_archive('../outside');self.refresh_download()
        with self.assertRaises(ValueError):setup.prepare(self.base,lambda message:True)
        self.assertFalse((self.base.parent/'outside').exists());self.assert_preserved()
    def test_existing_personal_destination_or_symlink_never_overwritten(self):
        target=self.base/'Print-RC';target.mkdir();(target/'personal.txt').write_text('keep')
        with self.assertRaises(ValueError):setup.prepare(self.base,lambda message:True)
        self.assertEqual((target/'personal.txt').read_text(),'keep')
        (target/'personal.txt').unlink();target.rmdir();target.symlink_to(self.base.parent,target_is_directory=True)
        with self.assertRaises(ValueError):setup.prepare(self.base,lambda message:True)
        setup.read_url.assert_not_called();self.assert_preserved()
    def test_existing_installation_is_not_replaced_or_updated(self):
        marker=self.base/'.print-rc-installation';marker.write_text('existing installation')
        with self.assertRaises(ValueError):setup.prepare(self.base,lambda message:True)
        self.assertEqual(marker.read_text(),'existing installation')
        setup.read_url.assert_not_called();self.assert_preserved()
    def test_atomic_publication_preserves_even_empty_concurrent_destination(self):
        prepared=self.base/'staged';prepared.mkdir();(prepared/'file').write_text('staged')
        target=self.base/'Print-RC';target.mkdir();before=target.stat().st_ino
        with self.assertRaises(FileExistsError):setup.publish(prepared,target)
        self.assertEqual(target.stat().st_ino,before);self.assertEqual(list(target.iterdir()),[])
        self.assertEqual((prepared/'file').read_text(),'staged')
    def test_runtime_failure_cleans_download_without_changing_preferences(self):
        with mock.patch.object(setup.subprocess,'run',return_value=mock.Mock(returncode=127,stdout='missing library')):
            with self.assertRaises(ValueError):setup.prepare(self.base,lambda message:True)
        self.assertFalse((self.base/'Print-RC').exists());self.assert_preserved()
    def test_unsupported_platform_is_rejected_before_question_or_network(self):
        self.platform.stop()
        with mock.patch.object(setup.platform,'machine',return_value='aarch64'):
            question=mock.Mock()
            with self.assertRaises(ValueError):setup.prepare(self.base,question)
            question.assert_not_called();setup.read_url.assert_not_called()
        self.assert_preserved()

if __name__=='__main__':unittest.main()

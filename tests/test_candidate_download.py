import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('candidate_notes',ROOT/'scripts/build/candidate_notes.py')
candidate=importlib.util.module_from_spec(spec);spec.loader.exec_module(candidate)

class CandidateDownloadTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.source='a'*40
        self.archive=self.root/'Print-RC-Linux-x86_64.zip'
        self.manifest_path=self.root/'build-manifest.json'
        # Headers only: publication validation fixtures, never executable/test evidence.
        self.elf=b'\x7fELF\x02\x01'+b'\0'*12+b'\x3e\0'+b'fixture'
        binary={'interpreter':'/lib64/ld-linux-x86-64.so.2','needed':['libc.so.6'],
                'sha256':hashlib.sha256(self.elf).hexdigest(),'symbol_requirements':{'GLIBC':'2.31','GLIBCXX':'3.4.28'}}
        self.manifest={'git_commit':self.source,'source_dirty':False,'architecture':'x86_64','backend':'x11',
                       'libc_family':'glibc','version':'0.6.0-dev',
                       'binaries':[dict(copy.deepcopy(binary),path=path) for path in candidate.BINARIES]}
    def package(self,omit=None,corrupt=None):
        self.manifest_path.write_text(json.dumps(self.manifest))
        with zipfile.ZipFile(self.archive,'w') as package:
            package.write(self.manifest_path,'Print-RC/build-manifest.json')
            for relative in candidate.BINARIES:
                if relative==omit:continue
                info=zipfile.ZipInfo('Print-RC/'+relative);info.external_attr=0o100755<<16
                package.writestr(info,b'bad executable' if relative==corrupt else self.elf)
            for relative in ('Instalar.desktop','Configurar.desktop','instalar.sh','iniciar.sh',
                             'scripts/desktop_install.py','src/main.cpp','LICENSE','package-files.json'):
                package.writestr('Print-RC/'+relative,'fixture')
    def validate(self):return candidate.validate(self.archive,self.manifest_path,self.source)
    def test_only_matching_complete_dynamic_package_passes(self):
        self.package();manifest,digest=self.validate()
        self.assertEqual(manifest,self.manifest)
        self.assertEqual(digest,hashlib.sha256(self.archive.read_bytes()).hexdigest())
    def test_other_commit_and_dirty_source_are_rejected(self):
        for changes in ({'git_commit':'b'*40},{'source_dirty':True}):
            with self.subTest(changes=changes):
                original=dict(self.manifest);self.manifest.update(changes);self.package()
                with self.assertRaises(ValueError):self.validate()
                self.manifest=original
    def test_source_zip_without_installer_is_rejected(self):
        self.package(omit='Instalar')
        with self.assertRaises(KeyError):self.validate()
    def test_corrupt_executable_is_rejected(self):
        self.package(corrupt='bin/print-rc')
        with self.assertRaisesRegex(ValueError,'ELF'):self.validate()
    def test_static_or_newer_abi_cannot_be_published_as_this_edition(self):
        for binary_change in ({'interpreter':None},{'symbol_requirements':{'GLIBC':'2.38'}}):
            with self.subTest(change=binary_change):
                self.set_binary=copy.deepcopy(self.manifest['binaries'][0])
                self.manifest['binaries'][0].update(binary_change);self.package()
                with self.assertRaises(ValueError):self.validate()
                self.manifest['binaries'][0]=self.set_binary

if __name__=='__main__':unittest.main()

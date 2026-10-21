import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('release_gate',ROOT/'scripts/build/release_gate.py')
gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)

class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.zip=self.root/'candidate.zip';self.zip.write_bytes(b'candidate')
        self.manifest={'source_dirty':False,'version':'0.6.0','architecture':'x86_64','backend':'x11',
                       'git_commit':'test-source','binaries':[{'interpreter':'/lib64/ld-linux-x86-64.so.2','needed':['libc.so.6'],
                       'symbol_requirements':{'GLIBC':'2.31','GLIBCXX':'3.4.28'}}]}
    def test_missing_real_desktop_evidence_blocks_release(self):
        with self.assertRaisesRegex(ValueError,'Missing acceptance evidence'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_too_new_abi_blocks_release(self):
        self.manifest['binaries'][0]['symbol_requirements']['GLIBC']='2.38'
        with self.assertRaisesRegex(ValueError,'ABI exceeds'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_static_glibc_blocks_release(self):
        self.manifest['binaries'][0]['interpreter']=None
        with self.assertRaisesRegex(ValueError,'dynamic glibc'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_development_version_blocks_release(self):
        self.manifest['version']='0.6.0-dev'
        with self.assertRaisesRegex(ValueError,'Development version'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_uncommitted_build_blocks_release(self):
        self.manifest['source_dirty']=True
        with self.assertRaisesRegex(ValueError,'clean and committed'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_wrong_artifact_hash_blocks_release(self):
        (self.root/(gate.REQUIRED[0]+'.json')).write_text(json.dumps({'target':gate.REQUIRED[0],'archive_sha256':'wrong','git_commit':'test-source'}))
        with self.assertRaisesRegex(ValueError,'does not match'):
            gate.validate(self.zip,self.manifest,self.root)

if __name__=='__main__':unittest.main()

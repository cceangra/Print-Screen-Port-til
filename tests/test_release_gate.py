import importlib.util
import hashlib
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
    def complete_evidence(self):
        log=self.root/'checks.txt';log.write_text('fixture only: never actual desktop acceptance')
        digest=hashlib.sha256(self.zip.read_bytes()).hexdigest()
        for target in gate.REQUIRED:
            zorin=target.startswith('zorin-');q4os=target.startswith('q4os-')
            data={'target':target,'archive_sha256':digest,'git_commit':'test-source',
                  'environment':{'os_release':'Zorin OS 17.3' if zorin else 'Q4OS' if q4os else 'Ubuntu 20.04',
                  'architecture':'x86_64','protocol':'x11','desktop':'XFCE' if zorin else 'Trinity' if q4os else 'Xvfb',
                  'libc':'glibc','libc_version':'2.35' if zorin else '2.41' if q4os else '2.31','libX11':'fixture'},
                  'test_kind':'virtual-machine-desktop' if zorin or q4os else 'xvfb',
                  'checks':dict.fromkeys(gate.CHECKS,True),'tested_at':'fixture',
                  'performance':{'repetitions':5,'latency_median_ms':10,'latency_p95_ms':12,'peak_rss_kib':100,
                  'peak_pss_kib':90,'cpu_seconds':.01,'baseline_peak_pss_kib':90,'baseline_latency_p95_ms':12},
                  'evidence_files':[{'path':'checks.txt','sha256':hashlib.sha256(log.read_bytes()).hexdigest()}]}
            (self.root/(target+'.json')).write_text(json.dumps(data))
        return self.root/(gate.REQUIRED[0]+'.json')
    def rewrite(self,path,change):
        data=json.loads(path.read_text());change(data);path.write_text(json.dumps(data))
    def test_complete_fixture_validates(self):
        self.complete_evidence()
        self.assertEqual(gate.validate(self.zip,self.manifest,self.root),hashlib.sha256(self.zip.read_bytes()).hexdigest())
    def test_xvfb_cannot_substitute_for_actual_zorin(self):
        path=self.complete_evidence();self.rewrite(path,lambda d:d.update(test_kind='xvfb'))
        with self.assertRaisesRegex(ValueError,'not full desktop'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_nonfinite_performance_rejected(self):
        path=self.complete_evidence();self.rewrite(path,lambda d:d['performance'].update(peak_pss_kib=float('nan')))
        with self.assertRaisesRegex(ValueError,'Missing measured performance'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_newer_runtime_cannot_substitute_for_old_baseline(self):
        self.complete_evidence();path=self.root/'builder-ubuntu-20.04.json'
        self.rewrite(path,lambda d:d['environment'].update(os_release='Ubuntu 24.04',libc_version='2.39'))
        with self.assertRaisesRegex(ValueError,'Baseline evidence'):
            gate.validate(self.zip,self.manifest,self.root)
    def test_log_symlink_parent_cannot_escape_evidence(self):
        path=self.complete_evidence()
        with tempfile.TemporaryDirectory() as temp:
            outside=Path(temp);(outside/'log').write_text('outside')
            (self.root/'linked').symlink_to(outside,target_is_directory=True)
            self.rewrite(path,lambda d:d.update(evidence_files=[{'path':'linked/log','sha256':hashlib.sha256(b'outside').hexdigest()}]))
            with self.assertRaisesRegex(ValueError,'escapes evidence directory'):
                gate.validate(self.zip,self.manifest,self.root)

if __name__=='__main__':unittest.main()

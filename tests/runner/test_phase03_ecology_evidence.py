"""Synthetic lossless-export checks, not gameplay evidence."""
import json
from pathlib import Path
import tempfile
import unittest
from test_phase03_ecology import rows_for
from phase03_ecology_evidence import write_bundle, read_bundle, digest, canonical


class EcologyEvidence(unittest.TestCase):
    def setUp(self):
        # Preserve fixture files; project forbids bulk/recursive deletion.
        self.base=Path(tempfile.mkdtemp(prefix='ecology-readable-fixture-'))
        self.output=self.base/'bundle'
        self.rows=rows_for(71)
        for row in self.rows:
            row['stats']['extra_lossless_check']={'none':None,'float':1.2345678901234567,'int':713,'bool':False,'unicode':'游戏'}
        self.manifest=write_bundle(self.rows,[71],self.output,120)
    def modify_manifest(self,change):
        p=self.output/'manifest.json';m=json.loads(p.read_text());change(m);p.write_text(json.dumps(m))
    def test_lossless_roundtrip_all_values(self):
        self.assertEqual(read_bundle(self.output),self.rows)
        self.assertEqual(self.manifest['canonical_rows_sha256'],digest(canonical(self.rows)))
    def test_12_transparent_uncompressed_files(self):
        self.assertEqual(len(self.manifest['files']),12)
        for name,info in self.manifest['files'].items():
            lines=(self.output/name).read_text().splitlines();self.assertEqual(len(lines),4)
            self.assertEqual(len(lines),info['rows']);self.assertNotIn('rules',json.loads(lines[0])['row'])
    def test_preexisting_directory_not_overwritten(self):
        with self.assertRaises(ValueError):write_bundle(self.rows,[71],self.output,120)
    def test_changed_rules_rejected(self):
        p=self.output/'rules.json';p.write_text(p.read_text()+' ')
        with self.assertRaisesRegex(ValueError,'Rules checksum'):read_bundle(self.output)
    def test_changed_data_rejected(self):
        p=self.output/next(iter(self.manifest['files']));p.write_text(p.read_text()+' ')
        with self.assertRaisesRegex(ValueError,'Evidence checksum'):read_bundle(self.output)
    def test_missing_declared_file_rejected(self):
        self.modify_manifest(lambda m:m['files'].pop(next(iter(m['files']))))
        with self.assertRaisesRegex(ValueError,'Missing/extra'):read_bundle(self.output)
    def test_path_traversal_manifest_rejected(self):
        self.modify_manifest(lambda m:m['files'].update({'../other':{}}))
        with self.assertRaisesRegex(ValueError,'Missing/extra'):read_bundle(self.output)
    def test_bad_canonical_rows_rejected(self):
        self.modify_manifest(lambda m:m.update(canonical_rows_sha256='0'*64))
        with self.assertRaisesRegex(ValueError,'Canonical raw'):read_bundle(self.output)
    def test_bad_row_count_rejected(self):
        self.modify_manifest(lambda m:m.update(rows=49))
        with self.assertRaisesRegex(ValueError,'Incomplete source'):read_bundle(self.output)
    def test_bad_stratum_rejected(self):
        self.modify_manifest(lambda m:m['files'][next(iter(m['files']))].update(stratum='other'))
        with self.assertRaisesRegex(ValueError,'Incorrect stratum'):read_bundle(self.output)
    def test_unknown_format_rejected(self):
        self.modify_manifest(lambda m:m.update(format='other'))
        with self.assertRaisesRegex(ValueError,'Unknown bundle'):read_bundle(self.output)
    def test_invalid_source_rows_rejected(self):
        with self.assertRaisesRegex(ValueError,'Incomplete factorial'):write_bundle(self.rows[:-1],[71],self.base/'bad',120)

if __name__=='__main__':unittest.main()

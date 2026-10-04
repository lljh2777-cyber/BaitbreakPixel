"""Strict raw-byte comparison guard tests, using small synthetic payloads."""
import base64
from copy import deepcopy
import gzip
import importlib.util
from pathlib import Path
import struct
import sys
import unittest

TOOLS=Path(__file__).resolve().parents[2]/'tools'
sys.path.insert(0,str(TOOLS))
import phase04_compare_presentation as compare

def b64(data): return base64.b64encode(data).decode()
def stream(values,mtime=0): return b64(gzip.compress(b''.join(struct.pack('<I',len(v))+v for v in values),mtime=mtime))

def report():
    rows=[]
    for spec in compare.SCENARIOS:
        ticks=[-1,*range(0,spec['ticks'],30),spec['ticks']-1]
        rows.append({'scenario':dict(spec),'checkpoints':[{'input_tick':t,'simulation_tick':max(t+1,0),
            'fish_wire_valid':True,'angler_wire_valid':True,'rng_seed':'9223372036854775807','rng_state':'-9223372036854775808',
            'payloads':{name:b64(b'full exact '+name.encode()) for name in compare.PAYLOADS}} for t in ticks],
            'input_trace_gzip':stream([b'input'+str(t).encode() for t in range(spec['ticks'])]),
            'every_tick_authority_gzip':stream([b'authority'+str(t).encode() for t in range(spec['ticks'])]),
            'witnesses':{name:True for name in compare.WITNESSES},
            'outcome':{name:False if name=='match_over' else '' if name=='reason' else 1 for name in compare.OUTCOME_FIELDS}})
    return {'format':'phase04-map-direct-equivalence-v1','engine':'4.7.2.stable.official.ed1daf0bf','schema':16,
        'probe':'synthetic comparator self-test, not gameplay evidence','registry_ref':{'id':'pond_v2','revision':1,'contract_version':1,'content_hash':'a'*64},
        'metadata_exclusions':[],'scenarios':rows,'passed':3791,'failed':0}

class RawEquivalenceTests(unittest.TestCase):
    def setUp(self): self.old=report(); self.new=deepcopy(self.old)
    def compare(self): return compare.compare(self.old,self.new)
    def test_identical(self): self.assertTrue(self.compare()['success'])
    def test_tick_difference_is_localized(self):
        values=compare.records(self.new['scenarios'][0]['every_tick_authority_gzip']);values[75]=b'changed'
        self.new['scenarios'][0]['every_tick_authority_gzip']=stream(values)
        result=self.compare();self.assertFalse(result['success']);self.assertEqual(result['scenarios'][0]['different_authority_ticks'],[75])
    def test_input_difference_is_localized(self):
        values=compare.records(self.new['scenarios'][0]['input_trace_gzip']);values[4]=b'changed'
        self.new['scenarios'][0]['input_trace_gzip']=stream(values)
        result=self.compare();self.assertFalse(result['success']);self.assertEqual(result['scenarios'][0]['different_inputs'],[4])
    def test_compression_metadata_is_not_gameplay(self):
        self.new['scenarios'][0]['input_trace_gzip']=stream(compare.records(self.old['scenarios'][0]['input_trace_gzip']),mtime=100)
        self.assertNotEqual(self.old['scenarios'][0]['input_trace_gzip'],self.new['scenarios'][0]['input_trace_gzip']);self.assertTrue(self.compare()['success'])
    def test_missing_tick_rejected_even_on_both_sides(self):
        self.old['scenarios'][0]['input_trace_gzip']=stream([b'one'])
        self.new=deepcopy(self.old);self.assertFalse(self.compare()['success'])
    def test_malformed_length_rejected(self):
        self.new['scenarios'][0]['input_trace_gzip']=b64(gzip.compress(struct.pack('<I',500)+b'short'))
        self.assertFalse(self.compare()['success'])
    def test_checkpoint_component_difference(self):
        self.new['scenarios'][0]['checkpoints'][0]['payloads']['fish_wire']=b64(b'private leak')
        result=self.compare();self.assertFalse(result['success']);self.assertIn([-1,'fish_wire'],result['scenarios'][0]['different_checkpoint_payloads'])
    def test_missing_checkpoint_rejected(self):
        self.new['scenarios'][0]['checkpoints'].pop();self.assertFalse(self.compare()['success'])
    def test_extra_component_rejected(self):
        self.new['scenarios'][0]['checkpoints'][0]['payloads']['unknown']=b64(b'extra');self.assertFalse(self.compare()['success'])
    def test_rng_precision_preserved(self):
        self.new['scenarios'][0]['checkpoints'][0]['rng_seed']='9223372036854775806';self.assertFalse(self.compare()['success'])
    def test_rng_number_not_text_rejected(self):
        self.new['scenarios'][0]['checkpoints'][0]['rng_seed']=9223372036854775807;self.assertFalse(self.compare()['success'])
    def test_witness_required(self):
        self.new['scenarios'][3]['witnesses']['entry']=False;self.assertFalse(self.compare()['success'])
    def test_map_identity_difference_rejected(self):
        self.new['registry_ref']['content_hash']='b'*64;self.assertFalse(self.compare()['success'])
    def test_metadata_exclusion_rejected(self):
        self.old['metadata_exclusions']=['map_ref'];self.new=deepcopy(self.old);self.assertFalse(self.compare()['success'])
    def test_error_count_rejected(self):
        self.new['failed']=1;self.assertFalse(self.compare()['success'])
    def test_incomplete_assertions_rejected(self):
        self.new['passed']=0;self.assertFalse(self.compare()['success'])
    def test_different_engine_rejected(self):
        self.new['engine']='4.6.1';self.assertFalse(self.compare()['success'])
    def test_noncanonical_base64_rejected(self):
        self.new['scenarios'][0]['checkpoints'][0]['payloads']['bait']='not base64!';self.assertFalse(self.compare()['success'])
    def test_public_validation_rejected(self):
        self.new['scenarios'][0]['checkpoints'][0]['fish_wire_valid']=False;self.assertFalse(self.compare()['success'])
    def test_tape_function_locks_body(self):
        self.assertEqual(compare.tape_function(b'func one() -> void:\n\tpass\n\nfunc two():\n\tpass\n','one'),b'func one() -> void:\n\tpass')
        with self.assertRaises(ValueError): compare.tape_function(b'func one(): pass','two')

if __name__=='__main__': unittest.main()

"""Escenarios de conectividad y fallos de cobertura de seguridad."""
import importlib.util
import ipaddress
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('security', ROOT / 'scripts/check_security.py')
security = importlib.util.module_from_spec(spec)
spec.loader.exec_module(security)

class Network(unittest.TestCase):
    profiles = json.loads((ROOT / 'infra/network-rules.json').read_text())
    addresses = dict(foundry=['10.123.4.0/25'], containers=['10.123.4.128/26'], privateEndpoints=['10.123.4.192/27'], appGateway=['10.123.4.224/27'], vaultEndpoint=['10.123.4.198'], cosmosEndpoint=['10.123.4.202','10.123.4.203'], clients=['10.121.0.0/24'], operators=['10.122.0.4'], monitor=['10.120.1.4'], dns=['10.120.0.4'])
    def access(self, purpose, direction, src, dst, port, protocol='Tcp'):
        def matches(token, address):
            if token == '*' or token == address:
                return True
            try:
                return any(ipaddress.ip_address(address) in ipaddress.ip_network(prefix) for prefix in self.addresses.get(token, [token]))
            except ValueError:
                return False
        for rule in sorted(self.profiles[purpose], key=lambda r:r['properties']['priority']):
            p = rule['properties']
            if p['direction'] != direction or p['protocol'] not in ('*', protocol):
                continue
            if not matches(p['sourceAddressPrefix'], src) or not matches(p['destinationAddressPrefix'], dst):
                continue
            for value in p['destinationPortRanges']:
                if value == '*' or (int(value.split('-')[0]) <= port <= int(value.split('-')[-1])):
                    return p['access']
        return 'DefaultAzureRule'
    def test_user_path(self):
        self.assertEqual(self.access('appGateway','Inbound','10.121.0.5','10.123.4.254',443),'Allow')
        self.assertEqual(self.access('containers','Inbound','10.121.0.5','10.123.4.140',443),'Deny')
        self.assertEqual(self.access('containers','Inbound','10.123.4.254','10.123.4.140',443),'Allow')
    def test_gateway_cannot_read_storage(self):
        for subnet, direction in [('appGateway','Outbound'),('privateEndpoints','Inbound')]:
            self.assertEqual(self.access(subnet,direction,'10.123.4.254','10.123.4.198',443),'Allow')
            self.assertEqual(self.access(subnet,direction,'10.123.4.254','10.123.4.197',443),'Deny')
    def test_cosmos_direct_scope(self):
        for subnet,direction in [('foundry','Outbound'),('privateEndpoints','Inbound')]:
            self.assertEqual(self.access(subnet,direction,'10.123.4.20','10.123.4.202',12000),'Allow')
            self.assertEqual(self.access(subnet,direction,'10.123.4.20','10.123.4.197',12000),'Deny')
    def test_no_general_egress_or_lateral_access(self):
        for purpose, source in [('foundry','10.123.4.20'),('containers','10.123.4.140')]:
            self.assertEqual(self.access(purpose,'Outbound',source,'8.8.8.8',443),'Deny')
            self.assertEqual(self.access(purpose,'Outbound',source,'10.125.0.4',443),'Deny')
            self.assertEqual(self.access(purpose,'Outbound',source,'10.120.0.4',53,'Udp'),'Allow')
    def test_rule_priorities(self):
        for rules in self.profiles.values():
            for direction in ('Inbound','Outbound'):
                priorities=[r['properties']['priority'] for r in rules if r['properties']['direction']==direction]
                self.assertEqual(len(priorities),len(set(priorities)))
                self.assertEqual(max(priorities),4096)

class Defender(unittest.TestCase):
    def fixture(self):
        plans={name:{'pricingTier':'Standard'} for name in ('KeyVaults','CosmosDbs','AI','CloudPosture')}
        plans['CloudPosture']['extensions']=[{'name':'ContainerRegistriesVulnerabilityAssessments','isEnabled':'True'}]
        stores={'storage':{'isEnabled':True,'malwareScanning':{'onUpload':{'isEnabled':True,'capGBPerMonth':1000}}},'agentStorage':{'isEnabled':True}}
        return plans,stores,{'networkRuleBypassOptions':'AzureServices'}
    def test_valid_configuration(self):
        self.assertEqual(security.assess(*self.fixture()),[])
    def test_missing_plan_or_scanner_fails(self):
        plans,stores,registry=self.fixture()
        del plans['KeyVaults']
        stores['storage']['malwareScanning']['onUpload']['isEnabled']=False
        errors=security.assess(plans,stores,registry)
        self.assertEqual(len(errors),2)
    def test_unreadable_scanner_cap_and_registry_access(self):
        plans,stores,registry=self.fixture()
        stores['storage']['malwareScanning']['onUpload'].pop('capGBPerMonth')
        registry['networkRuleBypassOptions']='None'
        self.assertEqual(len(security.assess(plans,stores,registry)),2)
    def test_risk_option_does_not_disable_defender(self):
        plans,stores,registry=self.fixture()
        stores['storage']={'isEnabled':False}
        self.assertTrue(security.assess(plans,stores,registry,False))

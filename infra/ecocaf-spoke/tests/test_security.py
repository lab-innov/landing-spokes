"""Contratos ECOCAF, incluidos casos de rechazo y límites de inventario."""
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/(name+'.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
checker=load('check_parameters');security=load('check_security')
SID='11111111-1111-1111-1111-111111111111'
def rid(kind):return f'/subscriptions/{SID}/resourceGroups/caf/providers/{kind}/central'
def foundation():return dict(tags={'iniciativa':'ECOCAF','DataClassification':'Interna'},functionAppName='func-ecocaf-new',planName='plan-ecocaf-new',storageAccountName='stecocafnew',vnetAddressPrefixes=['10.181.0.0/24'],subnetPrefixes={'privateEndpoints':'10.181.0.0/27','functionsIntegration':'10.181.0.64/26'},dnsServers=['10.179.0.4'],hubVnetResourceId=rid('Microsoft.Network/virtualNetworks'),routeTableResourceId=rid('Microsoft.Network/routeTables'),logAnalyticsWorkspaceResourceId=rid('Microsoft.OperationalInsights/workspaces'))
def active():return dict(foundation(),activateFunctionApp=True,inventoryVerified=True,networkVerified=True,defenderVerified=True,siemVerified=True,applicationVerified=True,securityApprovalId='CAF-123',allowedPrincipalIds=[SID],functionPrivateIps=['10.181.0.5'],apiClientPrefixes=['10.178.0.0/24'],monitorPrefixes=['10.179.1.4'],actionGroupResourceId=rid('Microsoft.Insights/actionGroups'))
class Parameters(unittest.TestCase):
    def test_foundation_and_activation(self):
        self.assertEqual(checker.check(foundation()),[]);self.assertEqual(checker.check(active()),[])
    def test_no_activation_without_inventory_or_security(self):
        for flag in ('inventoryVerified','networkVerified','defenderVerified','siemVerified','applicationVerified'):
            self.assertTrue(checker.check(dict(active(),**{flag:False})))
    def test_file_risk(self):
        self.assertTrue(checker.check(dict(active(),processesUntrustedFiles=True)))
        self.assertEqual(checker.check(dict(active(),processesUntrustedFiles=True,fileScanningVerified=True)),[])
    def test_invalid_network_and_permissions(self):
        for key,value in [('allowedOrigins',['*']),('functionAppName','azfun-POC-ECO-CAF-CR'),('functionPrivateIps',['10.181.0.1']),('routeTableResourceId','x'),('siemEventHubName','unpaired'),('extraEgress',[{'purpose':'functionsIntegration','destination':'0.0.0.0/0','ports':['*'],'justification':''}])]:
            self.assertTrue(checker.check(dict(foundation(),**{key:value})))
    def test_settings_rejection_does_not_disclose_values(self):
        errors=checker.check(dict(foundation(),applicationSettings={'AZUREWEBJOBSSTORAGE__clientId':'SECRET-DO-NOT-PRINT'}))
        self.assertTrue(errors);self.assertNotIn('SECRET-DO-NOT-PRINT',str(errors))
    def test_defender_does_not_imply_external_coverage(self):
        self.assertTrue(security.assess({},{}))
        plans={name:{'pricingTier':'Standard'} for name in ('AppServices','CloudPosture')}
        self.assertEqual(security.assess(plans,{'isEnabled':True}),[])
        self.assertTrue(security.assess(plans,{'isEnabled':False}))

class Template(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm=json.loads(Path(os.environ['ECO_ARM']).read_text());cls.resources=[]
        def walk(t):
            resources=t.get('resources',[])
            for r in resources.values() if isinstance(resources,dict) else resources:
                if r['type']=='Microsoft.Resources/deployments':walk(r['properties']['template'])
                else:cls.resources.append(r)
        walk(cls.arm)
    def test_no_public_or_unproven_services(self):
        forbidden={'Microsoft.Network/routeTables','Microsoft.Network/publicIPAddresses','Microsoft.Network/privateDnsZones','Microsoft.Network/privateEndpoints/privateDnsZoneGroups','Microsoft.Security/pricings','Microsoft.CognitiveServices/accounts','Microsoft.DocumentDB/databaseAccounts','Microsoft.ContainerRegistry/registries','Microsoft.KeyVault/vaults','Microsoft.App/containerApps'}
        for r in self.resources:
            self.assertNotIn(r['type'],forbidden)
            if 'publicNetworkAccess' in r.get('properties',{}):self.assertEqual(r['properties']['publicNetworkAccess'],'Disabled')
    def test_secure_settings_and_auth(self):
        self.assertEqual(self.arm['parameters']['applicationSettings']['type'],'secureObject')
        self.assertFalse(self.arm['parameters']['activateFunctionApp']['defaultValue'])
        auth=next(r for r in self.resources if r['type']=='Microsoft.Web/sites/config')['properties']
        self.assertEqual(auth['globalValidation']['unauthenticatedClientAction'],'Return401')
        self.assertIn('allowedPrincipals',auth['identityProviders']['azureActiveDirectory']['validation']['defaultAuthorizationPolicy'])
    def test_data_logging_defender_and_recovery(self):
        protection=next(r for r in self.resources if r['type']=='Microsoft.Security/defenderForStorageSettings')['properties']
        self.assertTrue(protection['isEnabled']);self.assertFalse(protection['overrideSubscriptionLevelSettings'])
        diag=[r for r in self.resources if r['type']=='Microsoft.Insights/diagnosticSettings']
        for service in ('blobServices','queueServices','tableServices'):
            self.assertTrue(any(service.lower() in json.dumps(r).lower() for r in diag))
        blob=next(r for r in self.resources if r['type']=='Microsoft.Storage/storageAccounts/blobServices')['properties']
        self.assertEqual(blob['deleteRetentionPolicy']['days'],14)
    def test_original_capacity_preserved(self):
        plan=next(r for r in self.resources if r['type']=='Microsoft.Web/serverfarms')
        self.assertEqual(plan['sku']['name'],'P1v3');self.assertEqual(plan['sku']['capacity'],1)
        storage=next(r for r in self.resources if r['type']=='Microsoft.Storage/storageAccounts')
        self.assertEqual(storage['sku']['name'],'Standard_LRS');self.assertFalse(storage['properties']['allowSharedKeyAccess'])

class Network(unittest.TestCase):
    profiles=json.loads((ROOT/'network-rules.json').read_text())
    addresses={'functionsIntegration':['10.181.0.64/26'],'privateEndpoints':['10.181.0.0/27'],'function':['10.181.0.5'],'clients':['10.178.0.0/24'],'operators':['10.177.0.4'],'dns':['10.179.0.4'],'monitor':['10.179.1.4']}
    def access(self,purpose,direction,source,destination,port):
        def match(token,address):
            if token=='*' or token==address:return True
            try:return any(ipaddress.ip_address(address) in ipaddress.ip_network(n) for n in self.addresses.get(token,[token]))
            except ValueError:return False
        for r in sorted(self.profiles[purpose],key=lambda r:r['properties']['priority']):
            p=r['properties']
            if p['direction']==direction and match(p['sourceAddressPrefix'],source) and match(p['destinationAddressPrefix'],destination) and ('*' in p['destinationPortRanges'] or str(port) in p['destinationPortRanges']):return p['access']
        return 'Default'
    def test_vpn_only_api_and_no_general_egress(self):
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.5',443),'Allow')
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.6',443),'Deny')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.181.0.6',443),'Allow')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','8.8.8.8',443),'Deny')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.179.0.4',53),'Allow')

if __name__=='__main__':unittest.main()

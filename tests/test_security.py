"""Contratos de seguridad y arquitectura de Smart Review."""
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/(name+'.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
checker=load('check_parameters');security=load('check_security')
SID='11111111-1111-1111-1111-111111111111'
def rid(kind,name='central'):return f'/subscriptions/{SID}/resourceGroups/caf/providers/{kind}/{name}'
def foundation():
    return dict(tags={'iniciativa':'SMARTREVIEW','DataClassification':'Interna','OpsDept':'DTI','UserDept':'Área funcional'},functionAppName='func-smartreview-new',functionPlanName='asp-smartreview-api-new',frontendAppName='app-smartreview-new',frontendPlanName='asp-smartreview-web-new',applicationInsightsName='appi-smartreview-new',hostStorageAccountName='stsmartreviewhostnew',businessStorageAccountName='stsmartreviewdocsnew',cosmosAccountName='cosmos-smartreview-new',openAiAccountName='oai-smartreview-new',documentIntelligenceAccountName='di-smartreview-new',keyVaultName='kv-smartreview-new',functionAuthenticationClientId=SID,frontendAuthenticationClientId=SID,vnetAddressPrefixes=['10.181.0.0/24'],subnetPrefixes={'privateEndpoints':'10.181.0.0/27','functionsIntegration':'10.181.0.64/26','frontendIntegration':'10.181.0.128/26'},routeTableResourceId=rid('Microsoft.Network/routeTables'),logAnalyticsWorkspaceResourceId=rid('Microsoft.OperationalInsights/workspaces'),siemAuthorizationRuleId=rid('Microsoft.EventHub/namespaces/ns/authorizationRules','send'),siemEventHubName='siem',privateDnsZoneResourceIds={service:f'/subscriptions/{SID}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/privatelink.{service}.example' for service in ('blob','queue','table','sites','cosmosSql','openAi','cognitiveServicesAccount','keyVault')})
def active():
    return dict(foundation(),models=[{'name':'approved','model':'approved-model','version':'approved-version','sku':'GlobalStandard','capacity':1}],modelsApproved=True,cosmosPrivateIps=['10.181.0.6'],fileScanningVerified=True,activateFunctionApp=True,activateFrontendApp=True,inventoryVerified=True,networkVerified=True,defenderVerified=True,siemVerified=True,monitoringPrivateLinkVerified=True,applicationVerified=True,securityApprovalId='CAF-123',allowedPrincipalIds=[SID],functionPrivateIps=['10.181.0.5'],frontendPrivateIps=['10.181.0.7'],apiClientPrefixes=['10.178.0.0/24'],monitorPrefixes=['10.179.1.4'],actionGroupResourceId=rid('Microsoft.Insights/actionGroups'))

class Parameters(unittest.TestCase):
    def test_foundation_and_activation(self):
        self.assertEqual(checker.check(foundation()),[]);self.assertEqual(checker.check(active()),[])
    def test_siem_is_mandatory(self):
        self.assertTrue(checker.check(dict(foundation(),siemEventHubName='')))
    def test_no_activation_without_controls(self):
        for flag in ('inventoryVerified','networkVerified','defenderVerified','siemVerified','monitoringPrivateLinkVerified','applicationVerified'):
            self.assertTrue(checker.check(dict(active(),**{flag:False})))
    def test_models_files_and_ips(self):
        for change in [dict(modelsApproved=False),dict(models=[]),dict(fileScanningVerified=False),dict(frontendPrivateIps=['10.181.0.5'])]:
            self.assertTrue(checker.check(dict(active(),**change)))
    def test_settings_rejection_does_not_disclose_values(self):
        errors=checker.check(dict(foundation(),functionApplicationSettings={'AZUREWEBJOBSSTORAGE__clientId':'SECRET-DO-NOT-PRINT'}))
        self.assertTrue(errors);self.assertNotIn('SECRET-DO-NOT-PRINT',str(errors))
    def test_defender_assessment(self):
        plans={name:{'pricingTier':'Standard'} for name in ('AppServices','CloudPosture','KeyVaults','CosmosDbs','AI')}
        storages={'hostStorage':{'isEnabled':True},'businessStorage':{'isEnabled':True,'malwareScanning':{'onUpload':{'isEnabled':True}}}}
        self.assertEqual(security.assess(plans,storages),[]);self.assertTrue(security.assess({},{}))

class Template(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm=json.loads(Path(os.environ['SMARTREVIEW_ARM']).read_text());cls.resources=[]
        def walk(t):
            resources=t.get('resources',[])
            for r in resources.values() if isinstance(resources,dict) else resources:
                if r['type']=='Microsoft.Resources/deployments':walk(r['properties']['template'])
                else:cls.resources.append(r)
        walk(cls.arm)
    def test_no_platform_resources(self):
        forbidden={'Microsoft.Network/publicIPAddresses','Microsoft.Network/privateDnsZones','Microsoft.Network/dnsForwardingRulesets','Microsoft.Network/virtualHubs','Microsoft.Network/hubVirtualNetworkConnections','Microsoft.Security/pricings','Microsoft.OperationalInsights/workspaces'}
        for r in self.resources:self.assertNotIn(r['type'],forbidden)
    def test_private_access_and_network_acls(self):
        for r in self.resources:
            if 'publicNetworkAccess' in r.get('properties',{}):self.assertEqual(r['properties']['publicNetworkAccess'],'Disabled')
        for r in (x for x in self.resources if x['type'] in ('Microsoft.Storage/storageAccounts','Microsoft.CognitiveServices/accounts') and not x.get('existing')):
            self.assertEqual(r['properties']['networkAcls']['defaultAction'],'Deny')
        self.assertEqual(len([r for r in self.resources if r['type']=='Microsoft.Network/privateEndpoints/privateDnsZoneGroups']),len([r for r in self.resources if r['type']=='Microsoft.Network/privateEndpoints']))
    def test_premium_plans_frontend_and_backend(self):
        plans=[r for r in self.resources if r['type']=='Microsoft.Web/serverfarms']
        self.assertEqual(len(plans),2)
        self.assertTrue(all(r['sku']['name']=='P1v4' and r['sku']['tier']=='PremiumV4' for r in plans))
        sites=[r for r in self.resources if r['type']=='Microsoft.Web/sites']
        self.assertEqual(len(sites),2);self.assertTrue(all(r['properties']['publicNetworkAccess']=='Disabled' for r in sites))
    def test_data_contracts(self):
        text=json.dumps(self.arm)
        for name in ('basedocuments','resoluciones','documents','batchs-gpt-temporal','outputs','contracts-dco-db','contracts','settings'):self.assertIn(name,text)
        self.assertIn('Standard_RAGRS',text)
        cosmos=next(r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts' and not r.get('existing'))
        self.assertTrue(cosmos['properties']['disableLocalAuth']);self.assertEqual(cosmos['properties']['backupPolicy']['type'],'Continuous')
    def test_auth_monitoring_and_siem(self):
        self.assertEqual(self.arm['parameters']['functionApplicationSettings']['type'],'secureObject')
        self.assertEqual(self.arm['parameters']['frontendApplicationSettings']['type'],'secureObject')
        self.assertFalse(self.arm['parameters']['activateFunctionApp']['defaultValue']);self.assertFalse(self.arm['parameters']['activateFrontendApp']['defaultValue'])
        insights=next(r for r in self.resources if r['type']=='Microsoft.Insights/components')
        self.assertEqual(insights['properties']['RetentionInDays'],90);self.assertEqual(insights['properties']['publicNetworkAccessForIngestion'],'Disabled')
        diagnostics=[r for r in self.resources if r['type']=='Microsoft.Insights/diagnosticSettings']
        self.assertTrue(diagnostics);self.assertTrue(all('eventHubAuthorizationRuleId' in r['properties'] and 'workspaceId' in r['properties'] for r in diagnostics))

class Network(unittest.TestCase):
    def test_three_profiles_and_default_deny(self):
        profiles=json.loads((ROOT/'infra/network-rules.json').read_text())
        self.assertEqual(set(profiles),{'privateEndpoints','functionsIntegration','frontendIntegration'})
        for rules in profiles.values():
            self.assertTrue(any(r['name']=='denegar-inbound' for r in rules));self.assertTrue(any(r['name']=='denegar-outbound' for r in rules))
        ipaddress.ip_network('10.181.0.128/26')

if __name__=='__main__':unittest.main()

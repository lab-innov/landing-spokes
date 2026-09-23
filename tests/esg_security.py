"""Contratos de infraestructura ESG y activación segura."""
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/f'{name}.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
params=load('check-esg-parameters');security=load('check-esg-security');acceptance=load('check-esg-acceptance')
SID='11111111-1111-1111-1111-111111111111'
def rid(kind):return f'/subscriptions/{SID}/resourceGroups/caf/providers/{kind}/central'
def foundation():
    zones={'blob':'privatelink.blob.core.windows.net','queue':'privatelink.queue.core.windows.net','table':'privatelink.table.core.windows.net','cognitiveServicesAccount':'privatelink.cognitiveservices.azure.com','openAi':'privatelink.openai.azure.com','aiServices':'privatelink.services.ai.azure.com','Sql':'privatelink.documents.azure.com','sites':'privatelink.azurewebsites.net','dataFactory':'privatelink.datafactory.azure.net','portal':'privatelink.adf.azure.com','databricks_ui_api':'privatelink.azuredatabricks.net','browser_authentication':'privatelink.azuredatabricks.net'}
    zone_ids={key:f'/subscriptions/{SID}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/{name}' for key,name in zones.items()}
    return dict(resourceGroupName='rg-esg-new',tags={'iniciativa':'ESG','DataClassification':'Interna','OpsDept':'DTI','UserDept':'GPFEI'},vnetAddressPrefixes=['10.180.0.0/21'],subnetPrefixes=dict(privateEndpoints='10.180.0.0/24',foundryAgents='10.180.1.0/24',functionsIntegration='10.180.2.0/26',databricksPublic='10.180.3.0/26',databricksPrivate='10.180.4.0/26'),existingRouteTableResourceId=rid('Microsoft.Network/routeTables'),existingLogAnalyticsWorkspaceResourceId=rid('Microsoft.OperationalInsights/workspaces'),privateDnsZoneResourceIds=zone_ids)
def activated():
    return dict(foundation(),activateWorkload=True,networkVerified=True,defenderVerified=True,siemVerified=True,applicationVerified=True,uploadGateVerified=True,securityApprovalId='CAF-123',actionGroupResourceId=rid('Microsoft.Insights/actionGroups'),functionAllowedPrincipalIds=[SID],functionPrivateIps=['10.180.0.5'],cosmosPrivateIps=['10.180.0.6'],apiClientPrefixes=['10.179.1.0/24'],monitorPrefixes=['10.179.2.4'])

class Parameters(unittest.TestCase):
    def test_stages(self):
        self.assertEqual(params.check(foundation()),[]);self.assertEqual(params.check(activated()),[])
    def test_activation_gates(self):
        for key in ('defenderVerified','siemVerified','networkVerified','applicationVerified','uploadGateVerified'):
            self.assertTrue(params.check(dict(activated(),**{key:False})))
    def test_invalid_inputs(self):
        for key,value in [('resourceGroupName','RG-POC-ESG-CR'),('cosmosPrivateIps',['10.181.0.5']),('tags',{}),('siemEventHubName','alone'),('extraEgress',[{'purpose':'functionsIntegration','destination':'0.0.0.0/0','ports':['*'],'justification':''}])]:
            self.assertTrue(params.check(dict(foundation(),**{key:value})))
        p=foundation();p['subnetPrefixes']['databricksPrivate']='10.180.3.0/26';self.assertTrue(params.check(p))
    def test_models_and_grounding_require_approval(self):
        self.assertTrue(params.check(dict(foundation(),deployGroundingWithBing=True)))
        self.assertTrue(params.check(dict(foundation(),foundryModelDeployments=[dict(name='m',model='m',version='v',sku='s',capacity=1,raiPolicy='p')])))
    def test_configuration_is_not_effective_protection(self):
        self.assertTrue(security.assess({},{}))
        plans={k:{'pricingTier':'Standard'} for k in ('CloudPosture','AppServices','CosmosDbs','AI')}
        stores={'workloadStorage':{'isEnabled':True,'malwareScanning':{'onUpload':{'isEnabled':True,'capGBPerMonth':1000}}},'functionStorage':{'isEnabled':True}}
        self.assertEqual(security.assess(plans,stores),[])
        stores['workloadStorage']['malwareScanning']['onUpload']['isEnabled']=False
        self.assertTrue(security.assess(plans,stores))
    def test_trigger_gate_expiration_and_scope(self):
        now=dt.datetime.now(dt.timezone.utc)
        e=dict(resourceGroup='rg-esg',dataFactory='adf',approvalId='CAF-123',approvedBy='responsable',approvedAt=now.isoformat(),networkVerified=True,defenderVerified=True,siemVerified=True,applicationVerified=True,dataMigrationVerified=True,pipelineTestsVerified=True,uploadGateVerified=True)
        self.assertEqual(acceptance.check(e,'rg-esg','adf',now),[])
        self.assertTrue(acceptance.check(e,'otro','adf',now))
        self.assertTrue(acceptance.check(e,'rg-esg','adf',now+dt.timedelta(days=8)))
        self.assertTrue(acceptance.check(dict(e,uploadGateVerified=False),'rg-esg','adf',now))

class Template(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm=json.loads(Path(os.environ['ESG_ARM']).read_text());cls.resources=[]
        def walk(t):
            rs=t.get('resources',[])
            for r in rs.values() if isinstance(rs,dict) else rs:
                if r['type']=='Microsoft.Resources/deployments':walk(r['properties']['template'])
                else:cls.resources.append(r)
        walk(cls.arm)
    def test_no_public_or_duplicate_platform(self):
        forbidden={'Microsoft.Network/publicIPAddresses','Microsoft.Network/privateDnsZones','Microsoft.Network/privateDnsZones/virtualNetworkLinks','Microsoft.Network/virtualNetworks/virtualNetworkPeerings','Microsoft.Insights/components','Microsoft.Network/azureFirewalls','Microsoft.Network/virtualNetworkGateways','Microsoft.OperationalInsights/workspaces','Microsoft.Security/pricings'}
        for r in self.resources:
            self.assertNotIn(r['type'],forbidden)
            if 'publicNetworkAccess' in r.get('properties',{}):self.assertEqual(r['properties']['publicNetworkAccess'],'Disabled')
        self.assertEqual(len([r for r in self.resources if r['type']=='Microsoft.Network/privateEndpoints/privateDnsZoneGroups']),len([r for r in self.resources if r['type']=='Microsoft.Network/privateEndpoints']))
        endpoints=json.dumps(self.arm['resources']['privateEndpoints']['properties']['parameters']['endpoints'])
        for zone in ('cognitiveServicesAccount','openAi','aiServices'):
            self.assertIn(zone,endpoints)
    def test_storage_data_audit_and_protection(self):
        protections=[r for r in self.resources if r['type']=='Microsoft.Security/defenderForStorageSettings'];self.assertEqual(len(protections),2)
        for r in protections:
            self.assertTrue(r['properties']['isEnabled']);self.assertFalse(r['properties']['overrideSubscriptionLevelSettings'])
        diag=[r for r in self.resources if r['type']=='Microsoft.Insights/diagnosticSettings']
        for service in ('blobServices','queueServices','tableServices'):
            self.assertTrue(any(service.lower() in json.dumps(r).lower() for r in diag))
    def test_auth_and_activation(self):
        app=next(r for r in self.resources if r['type']=='Microsoft.Web/sites')
        self.assertIn('activateWorkload',app['properties']['enabled'])
        auth=next(r for r in self.resources if r['type']=='Microsoft.Web/sites/config')['properties']
        self.assertTrue(auth['globalValidation']['requireAuthentication'])
        self.assertEqual(auth['globalValidation']['unauthenticatedClientAction'],'Return401')
        self.assertIn('allowedPrincipals',auth['identityProviders']['azureActiveDirectory']['validation']['defaultAuthorizationPolicy'])
    def test_cosmos_contract_unchanged_and_scope_reduced(self):
        containers=[r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers']
        self.assertEqual([r['properties']['resource']['partitionKey']['paths'] for r in containers],[['/id','/createdAt','/isActive'],['/id']])
        role=next(r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments')
        self.assertIn('/dbs/esg-db',role['properties']['scope'])
    def test_models_are_explicit_and_alerts_exist(self):
        for name in ('foundryModelDeployments','openAiModelDeployments'):
            self.assertEqual(self.arm['parameters'][name]['defaultValue'],[])
        for r in self.resources:
            if r['type']=='Microsoft.CognitiveServices/accounts/deployments':
                self.assertEqual(r['properties']['versionUpgradeOption'],'NoAutoUpgrade')
        self.assertTrue(any(r['type']=='Microsoft.Insights/metricAlerts' for r in self.resources))

    def test_network_policy_has_final_denies(self):
        profiles=json.loads((ROOT/'infra/esg-spoke/network-rules.json').read_text())
        for rules in profiles.values():
            self.assertEqual({r['properties']['direction'] for r in rules if r['properties']['access']=='Deny'},{'Inbound','Outbound'})
            self.assertFalse(any(r['properties']['sourceAddressPrefix']=='VirtualNetwork' for r in rules))
        pe=profiles['privateEndpoints']
        cosmos=[r for r in pe if r['properties']['destinationPortRanges']==['0-65535']]
        self.assertTrue(cosmos);self.assertTrue(all(r['properties']['destinationAddressPrefix']=='cosmos' for r in cosmos))

if __name__=='__main__':unittest.main()

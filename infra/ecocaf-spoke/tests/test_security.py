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
def foundation():
    zones={'blob':'privatelink.blob.core.windows.net','dfs':'privatelink.dfs.core.windows.net','queue':'privatelink.queue.core.windows.net','table':'privatelink.table.core.windows.net','sites':'privatelink.azurewebsites.net','cosmosSql':'privatelink.documents.azure.com','cognitiveServicesAccount':'privatelink.cognitiveservices.azure.com','openAi':'privatelink.openai.azure.com'}
    zone_ids={service:f'/subscriptions/{SID}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/{name}' for service,name in zones.items()}
    return dict(tags={'iniciativa':'ECOCAF','DataClassification':'Interna','OpsDept':'DTI','UserDept':'DATBC'},functionAppName='func-ecocaf-new',planName='plan-ecocaf-new',frontendAppName='app-ecocaf-new',frontendPlanName='plan-ecocaf-web-new',storageAccountName='stecocafhostnew',businessStorageAccountName='stecocafdocsnew',cosmosAccountName='cosmos-ecocaf-new',openAiAccountName='oai-ecocaf-new',documentIntelligenceAccountName='di-ecocaf-new',vnetAddressPrefixes=['10.181.0.0/24'],subnetPrefixes={'privateEndpoints':'10.181.0.0/27','functionsIntegration':'10.181.0.64/26','frontendIntegration':'10.181.0.128/26'},routeTableResourceId=rid('Microsoft.Network/routeTables'),logAnalyticsWorkspaceResourceId=rid('Microsoft.OperationalInsights/workspaces'),privateDnsZoneResourceIds=zone_ids,models=[],modelsApproved=False,openAiApiVersion='2025-04-01-preview',commonServiceUrls={'audits':'https://audits.internal.example','notifications':'https://notifications.internal.example','pdfConverter':'https://pdf.internal.example'},commonServicesVerified=False,identityMigrationVerified=False,processesUntrustedFiles=True)
def active():return dict(foundation(),activateFunctionApp=True,models=[{'name':'gpt-4o','model':'gpt-4o','version':'2024-11-20','sku':'GlobalStandard','capacity':1}],modelsApproved=True,commonServicesVerified=True,identityMigrationVerified=True,inventoryVerified=True,networkVerified=True,defenderVerified=True,siemVerified=True,applicationVerified=True,securityApprovalId='CAF-123',allowedPrincipalIds=[SID],functionPrivateIps=['10.181.0.5'],apiClientPrefixes=['10.178.0.0/24'],monitorPrefixes=['10.179.1.4'],actionGroupResourceId=rid('Microsoft.Insights/actionGroups'),fileScanningVerified=True)
class Parameters(unittest.TestCase):
    def test_foundation_and_activation(self):
        self.assertEqual(checker.check(foundation()),[]);self.assertEqual(checker.check(active()),[])
    def test_no_activation_without_inventory_or_security(self):
        for flag in ('inventoryVerified','networkVerified','defenderVerified','siemVerified','applicationVerified'):
            self.assertTrue(checker.check(dict(active(),**{flag:False})))
    def test_file_risk(self):
        self.assertTrue(checker.check(dict(active(),fileScanningVerified=False)))
        self.assertEqual(checker.check(dict(active(),processesUntrustedFiles=True,fileScanningVerified=True)),[])
    def test_frontend_activation(self):
        self.assertTrue(checker.check(dict(active(),activateFrontend=True)))
        configured=dict(active(),activateFrontend=True,frontendApplicationVerified=True,frontendAllowedPrincipalIds=[SID],frontendPrivateIps=['10.181.0.6'],frontendApplicationSettings={'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET':'NO-IMPRIMIR'})
        self.assertEqual(checker.check(configured),[])
    def test_invalid_network_and_permissions(self):
        for key,value in [('allowedOrigins',['*']),('functionAppName','azfun-POC-ECO-CAF-CR'),('functionPrivateIps',['10.181.0.1']),('routeTableResourceId','x'),('siemEventHubName','unpaired'),('extraEgress',[{'purpose':'functionsIntegration','destination':'0.0.0.0/0','ports':['*'],'justification':''}])]:
            self.assertTrue(checker.check(dict(foundation(),**{key:value})))
    def test_settings_rejection_does_not_disclose_values(self):
        errors=checker.check(dict(foundation(),applicationSettings={'AZUREWEBJOBSSTORAGE__clientId':'SECRET-DO-NOT-PRINT'}))
        self.assertTrue(errors);self.assertNotIn('SECRET-DO-NOT-PRINT',str(errors))
    def test_defender_does_not_imply_external_coverage(self):
        self.assertTrue(security.assess({},{}))
        plans={name:{'pricingTier':'Standard'} for name in ('AppServices','CloudPosture','AI','CosmosDbs')}
        self.assertEqual(security.assess(plans,{'isEnabled':True}),[])
        self.assertTrue(security.assess(plans,{'isEnabled':False}))

class Template(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm=json.loads(Path(os.environ['ECO_ARM']).read_text());cls.resources=[];cls.all_deployments=[]
        root_resources=cls.arm.get('resources',[])
        cls.deployments=[r for r in (root_resources.values() if isinstance(root_resources,dict) else root_resources) if r['type']=='Microsoft.Resources/deployments']
        def walk(t):
            resources=t.get('resources',[])
            for r in resources.values() if isinstance(resources,dict) else resources:
                if r['type']=='Microsoft.Resources/deployments':
                    cls.all_deployments.append(r);walk(r['properties']['template'])
                else:cls.resources.append(r)
        walk(cls.arm)
    def test_no_public_or_unproven_services(self):
        forbidden={'Microsoft.Network/routeTables','Microsoft.Network/publicIPAddresses','Microsoft.Network/privateDnsZones','Microsoft.Network/virtualNetworks/virtualNetworkPeerings','Microsoft.Insights/components','Microsoft.Security/pricings','Microsoft.ContainerRegistry/registries','Microsoft.KeyVault/vaults','Microsoft.App/containerApps','Microsoft.DataFactory/factories','Microsoft.Databricks/workspaces'}
        for r in self.resources:
            self.assertNotIn(r['type'],forbidden)
            if 'publicNetworkAccess' in r.get('properties',{}):self.assertEqual(r['properties']['publicNetworkAccess'],'Disabled')
        endpoints=[r for r in self.resources if r['type']=='Microsoft.Network/privateEndpoints']
        zone_groups=[r for r in self.resources if r['type']=='Microsoft.Network/privateEndpoints/privateDnsZoneGroups']
        self.assertGreaterEqual(len(endpoints),2)
        self.assertEqual(len(zone_groups),len(endpoints))
        for endpoint in endpoints:
            connections=endpoint['properties'].get('privateLinkServiceConnections',[])
            self.assertEqual(len(connections),1)
            connection=connections[0]['properties']
            self.assertTrue(connection.get('privateLinkServiceId'))
            self.assertTrue(connection.get('groupIds'))
            self.assertFalse(endpoint['properties'].get('manualPrivateLinkServiceConnections'))
        for group in zone_groups:
            self.assertIn('privateDnsZoneConfigs',json.dumps(group['properties']))
            self.assertIn('privateDnsZoneId',json.dumps(group['properties']))
        pe_deployments=[d for d in self.deployments if 'privateLinkServiceId' in d['properties'].get('parameters',{})]
        self.assertGreaterEqual(len(pe_deployments),3)
        deployment_contract=json.dumps({'deployments':pe_deployments,'variables':self.arm.get('variables',{})})
        for group_id in ('blob','dfs','queue','table','sites','Sql','account'):
            self.assertIn(group_id,deployment_contract)
        self.assertIn('privateLinkServiceId',deployment_contract)
    def test_secure_settings_and_auth(self):
        self.assertEqual(self.arm['parameters']['applicationSettings']['type'],'secureObject')
        self.assertFalse(self.arm['parameters']['activateFunctionApp']['defaultValue'])
        auth=[r['properties'] for r in self.resources if r['type']=='Microsoft.Web/sites/config']
        self.assertTrue(any(item['globalValidation']['unauthenticatedClientAction']=='Return401' for item in auth))
        self.assertTrue(any(item['globalValidation']['unauthenticatedClientAction']=='RedirectToLoginPage' for item in auth))
        self.assertTrue(all('allowedPrincipals' in item['identityProviders']['azureActiveDirectory']['validation']['defaultAuthorizationPolicy'] for item in auth))
    def test_data_logging_defender_and_recovery(self):
        protections=[r['properties'] for r in self.resources if r['type']=='Microsoft.Security/defenderForStorageSettings']
        self.assertEqual(len(protections),2)
        self.assertTrue(all(item['isEnabled'] and not item['overrideSubscriptionLevelSettings'] for item in protections))
        diag=[r for r in self.resources if r['type']=='Microsoft.Insights/diagnosticSettings']
        for service in ('blobServices','queueServices','tableServices'):
            self.assertTrue(any(service.lower() in json.dumps(r).lower() for r in diag))
        blob=next(r for r in self.resources if r['type']=='Microsoft.Storage/storageAccounts/blobServices')['properties']
        self.assertEqual(blob['deleteRetentionPolicy']['days'],14)
    def test_requested_plan_and_storage_capacity(self):
        plans=[r for r in self.resources if r['type']=='Microsoft.Web/serverfarms']
        self.assertTrue(any(plan['sku']['name']=='P1v4' and plan['sku']['tier']=='PremiumV4' and plan['sku']['capacity']==1 for plan in plans))
        self.assertTrue(any(plan['sku']['name']=='B1' and plan['sku']['tier']=='Basic' and plan['sku']['capacity']==1 for plan in plans))
        storage=[r for r in self.resources if r['type']=='Microsoft.Storage/storageAccounts']
        self.assertEqual(len(storage),2)
        self.assertTrue(all(item['sku']['name']=='Standard_LRS' and not item['properties']['allowSharedKeyAccess'] for item in storage))
        business=next(d for d in self.deployments if d['name']=='ecocaf-datos')
        host=next(d for d in self.deployments if d['name']=='ecocaf-storage')
        self.assertIs(business['properties']['parameters']['isHnsEnabled']['value'],True)
        self.assertNotIn('isHnsEnabled',host['properties']['parameters'])
    def test_dedicated_business_services(self):
        cosmos=next(r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts')
        self.assertTrue(cosmos['properties']['disableLocalAuth'])
        self.assertEqual(cosmos['properties']['publicNetworkAccess'],'Disabled')
        serialized=json.dumps(self.resources)
        for name in ('EcoCAF','Documents','Proyectos','Auditoria','Logs'):
            self.assertIn(name,serialized)
        cognitive=[r for r in self.resources if r['type']=='Microsoft.CognitiveServices/accounts']
        kinds={d['properties']['parameters']['kind']['value'] for d in self.all_deployments if 'kind' in d['properties'].get('parameters',{})}
        self.assertEqual(kinds,{'OpenAI','FormRecognizer'})
        self.assertTrue(all(item['properties']['disableLocalAuth'] and item['properties']['publicNetworkAccess']=='Disabled' for item in cognitive))
        self.assertNotIn('Microsoft.DataFactory/factories',serialized)
        self.assertNotIn('Microsoft.Databricks/workspaces',serialized)

class Network(unittest.TestCase):
    profiles=json.loads((ROOT/'network-rules.json').read_text())
    addresses={'functionsIntegration':['10.181.0.64/26'],'frontendIntegration':['10.181.0.128/26'],'privateEndpoints':['10.181.0.0/27'],'function':['10.181.0.5'],'frontend':['10.181.0.6'],'clients':['10.178.0.0/24'],'operators':['10.177.0.4'],'monitor':['10.179.1.4']}
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
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.6',443),'Allow')
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.7',443),'Deny')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.181.0.6',443),'Allow')
        self.assertEqual(self.access('frontendIntegration','Outbound','10.181.0.130','10.181.0.5',443),'Allow')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','8.8.8.8',443),'Deny')
        dns=next(r for r in self.profiles['functionsIntegration'] if r['name']=='dns-plataforma')
        self.assertEqual(dns['properties']['destinationAddressPrefix'],'AzurePlatformDNS')

if __name__=='__main__':unittest.main()

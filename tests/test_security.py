"""Contratos VINCULADOR, incluidos casos de rechazo y límites de inventario."""
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/(name+'.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
checker=load('check_parameters');security=load('check_security')
SID='11111111-1111-1111-1111-111111111111'
def rid(kind):return f'/subscriptions/{SID}/resourceGroups/caf/providers/{kind}/central'
def foundation():return dict(tags={'iniciativa':'VINCULADOR','DataClassification':'Interna'},functionAppName='func-vinculador-new',planName='plan-vinculador-new',storageAccountName='stvinculadornew',businessStorageAccountName='stvinculadordocs',cosmosAccountName='cosmos-vinculador-new',openAiAccountName='oai-vinculador-new',documentIntelligenceAccountName='di-vinculador-new',dataFactoryName='adf-vinculador-new',vnetAddressPrefixes=['10.181.0.0/24'],subnetPrefixes={'privateEndpoints':'10.181.0.0/27','functionsIntegration':'10.181.0.64/26'},dnsServers=['10.179.0.4'],hubVnetResourceId=rid('Microsoft.Network/virtualNetworks'),routeTableResourceId=rid('Microsoft.Network/routeTables'),logAnalyticsWorkspaceResourceId=rid('Microsoft.OperationalInsights/workspaces'))
def active():return dict(foundation(),orchestrationVerified=True,processorPrefixes=['10.180.0.0/26'],processorDataPrivateIps=['10.181.0.6','10.181.0.7'],models=[{'name':'approved','model':'approved-model','version':'approved-version','sku':'GlobalStandard','capacity':1}],modelsApproved=True,cosmosPrivateIps=['10.181.0.6'],fileScanningVerified=True,activateFunctionApp=True,inventoryVerified=True,networkVerified=True,defenderVerified=True,siemVerified=True,applicationVerified=True,securityApprovalId='CAF-123',allowedPrincipalIds=[SID],functionPrivateIps=['10.181.0.5'],apiClientPrefixes=['10.178.0.0/24'],monitorPrefixes=['10.179.1.4'],actionGroupResourceId=rid('Microsoft.Insights/actionGroups'))
class Parameters(unittest.TestCase):
    def test_foundation_and_activation(self):
        self.assertEqual(checker.check(foundation()),[]);self.assertEqual(checker.check(active()),[])
    def test_no_activation_without_inventory_or_security(self):
        for flag in ('inventoryVerified','networkVerified','defenderVerified','siemVerified','applicationVerified'):
            self.assertTrue(checker.check(dict(active(),**{flag:False})))
    def test_models_and_private_ips(self):
        for change in [dict(modelsApproved=False),dict(cosmosPrivateIps=['10.181.0.1']),dict(models=[]),dict(models=[{'name':'batch','model':'m','version':'v','sku':'GlobalBatch','capacity':1}])]:
            self.assertTrue(checker.check(dict(active(),**change)))
        self.assertTrue(checker.check(dict(foundation(),vnetAddressPrefixes=['10.181.0.0/23'])))
    def test_blob_identity_and_orchestration_gate(self):
        self.assertTrue(checker.check(dict(foundation(),hostUsesBlobTriggers=False)))
        self.assertTrue(checker.check(dict(foundation(),applicationSettings={'BLOB_STORAGE_CONNECTION_STRING':'NO-PUBLICAR'})))
        self.assertTrue(checker.check(dict(active(),orchestrationVerified=False)))
        self.assertTrue(checker.check(dict(foundation(),allowTrustedStorageServices=True)))
    def test_file_risk(self):
        self.assertTrue(checker.check(dict(active(),processesUntrustedFiles=True,fileScanningVerified=False)))
        self.assertEqual(checker.check(dict(active(),processesUntrustedFiles=True,fileScanningVerified=True)),[])
    def test_invalid_network_and_permissions(self):
        for key,value in [('allowedOrigins',['*']),('functionAppName','azfun-POC-VINCULADOR-CR'),('functionPrivateIps',['10.181.0.1']),('routeTableResourceId','x'),('siemEventHubName','unpaired'),('extraEgress',[{'purpose':'functionsIntegration','destination':'0.0.0.0/0','ports':['*'],'justification':''}])]:
            self.assertTrue(checker.check(dict(foundation(),**{key:value})))
    def test_settings_rejection_does_not_disclose_values(self):
        errors=checker.check(dict(foundation(),applicationSettings={'AZUREWEBJOBSSTORAGE__clientId':'SECRET-DO-NOT-PRINT'}))
        self.assertTrue(errors);self.assertNotIn('SECRET-DO-NOT-PRINT',str(errors))
    def test_defender_does_not_imply_external_coverage(self):
        self.assertTrue(security.assess({},{}))
        plans={name:{'pricingTier':'Standard'} for name in ('AppServices','CloudPosture','CosmosDbs','AI')}
        self.assertEqual(security.assess(plans,{'hostStorage':{'isEnabled':True},'businessStorage':{'isEnabled':True,'malwareScanning':{'onUpload':{'isEnabled':True}}}}),[])
        self.assertTrue(security.assess(plans,{'isEnabled':False}))

class Template(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm=json.loads(Path(os.environ['VINCULADOR_ARM']).read_text());cls.resources=[]
        def walk(t):
            resources=t.get('resources',[])
            for r in resources.values() if isinstance(resources,dict) else resources:
                if r['type']=='Microsoft.Resources/deployments':walk(r['properties']['template'])
                else:cls.resources.append(r)
        walk(cls.arm)
    def test_no_public_or_unproven_services(self):
        forbidden={'Microsoft.Network/routeTables','Microsoft.Network/publicIPAddresses','Microsoft.Network/privateDnsZones','Microsoft.Network/privateEndpoints/privateDnsZoneGroups','Microsoft.Security/pricings','Microsoft.ContainerRegistry/registries','Microsoft.App/containerApps'}
        for r in self.resources:
            self.assertNotIn(r['type'],forbidden)
            self.assertNotEqual(r['type'],'Microsoft.OperationalInsights/workspaces')
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
    def test_cosmos_schema_and_batch_scope(self):
        db=next(r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts/sqlDatabases')
        self.assertIn('databaseName',str(db['properties']))
        container=next(r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers')
        self.assertEqual(container['properties']['resource']['partitionKey']['paths'],['/id'])
        cosmos=next(r for r in self.resources if r['type']=='Microsoft.DocumentDB/databaseAccounts' and not r.get('existing'))
        self.assertTrue(cosmos['properties']['disableLocalAuth'])
        self.assertEqual(cosmos['properties']['backupPolicy']['type'],'Continuous')
        role=next(r for r in self.resources if r['type']=='Microsoft.Authorization/roleDefinitions')
        self.assertEqual(role['properties']['permissions'][0]['actions'],[])
        self.assertIn('Microsoft.CognitiveServices/accounts/OpenAI/batch-jobs/write',role['properties']['permissions'][0]['dataActions'])
        self.assertNotIn('*',str(role['properties']['permissions']))
        self.assertEqual(self.arm['parameters']['models']['defaultValue'],[])
        for account in (r for r in self.resources if r['type']=='Microsoft.CognitiveServices/accounts' and not r.get('existing')):
            self.assertEqual(account['properties']['networkAcls']['bypass'],'None')
            self.assertTrue(account['properties']['disableLocalAuth'])
        self.assertEqual(self.arm['resources']['serviceEndpoints']['copy']['count'],"[length(range(0, 5))]")
        self.assertIn('serviceEndpoints',str(self.arm['resources']['runtime']['dependsOn']))
        self.assertIn('storageEndpoints',str(self.arm['resources']['runtime']['dependsOn']))
        self.assertFalse(self.arm['parameters']['hostUsesDurableStorage']['defaultValue'])
        self.assertTrue(self.arm['parameters']['hostUsesBlobTriggers']['defaultValue'])
        self.assertTrue(self.arm['parameters']['processesUntrustedFiles']['defaultValue'])
    def test_original_capacity_preserved(self):
        plan=next(r for r in self.resources if r['type']=='Microsoft.Web/serverfarms')
        self.assertEqual(plan['sku']['name'],'P1v3');self.assertEqual(plan['sku']['capacity'],1)
        storage=next(r for r in self.resources if r['type']=='Microsoft.Storage/storageAccounts')
        self.assertEqual(storage['sku']['name'],'Standard_LRS');self.assertFalse(storage['properties']['allowSharedKeyAccess'])

class Network(unittest.TestCase):
    profiles=json.loads((ROOT/'infra/network-rules.json').read_text())
    addresses={'functionsIntegration':['10.181.0.64/26'],'privateEndpoints':['10.181.0.0/27'],'function':['10.181.0.5'],'cosmos':['10.181.0.6'],'processor':['10.180.0.0/26'],'processorData':['10.181.0.6','10.181.0.7'],'clients':['10.178.0.0/24'],'operators':['10.177.0.4'],'dns':['10.179.0.4'],'monitor':['10.179.1.4']}
    def access(self,purpose,direction,source,destination,port):
        def match(token,address):
            if token=='*' or token==address:return True
            try:return any(ipaddress.ip_address(address) in ipaddress.ip_network(n) for n in self.addresses.get(token,[token]))
            except ValueError:return False
        for r in sorted(self.profiles[purpose],key=lambda r:r['properties']['priority']):
            p=r['properties']
            if p['direction']==direction and match(p['sourceAddressPrefix'],source) and match(p['destinationAddressPrefix'],destination) and ('*' in p['destinationPortRanges'] or str(port) in p['destinationPortRanges'] or any('-' in q and int(q.split('-')[0])<=port<=int(q.split('-')[1]) for q in p['destinationPortRanges'])):return p['access']
        return 'Default'
    def test_processor_cannot_reach_function_or_host(self):
        self.assertEqual(self.access('privateEndpoints','Inbound','10.180.0.5','10.181.0.7',443),'Allow')
        self.assertEqual(self.access('privateEndpoints','Inbound','10.180.0.5','10.181.0.5',443),'Deny')
        self.assertEqual(self.access('privateEndpoints','Inbound','10.180.0.5','10.181.0.8',443),'Deny')
    def test_cosmos_direct_is_scoped(self):
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.181.0.6',12000),'Allow')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.181.0.7',12000),'Deny')
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.6',12000),'Deny')
    def test_vpn_only_api_and_no_general_egress(self):
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.5',443),'Allow')
        self.assertEqual(self.access('privateEndpoints','Inbound','10.178.0.5','10.181.0.6',443),'Deny')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.181.0.6',443),'Allow')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','8.8.8.8',443),'Deny')
        self.assertEqual(self.access('functionsIntegration','Outbound','10.181.0.70','10.179.0.4',53),'Allow')

class Orchestration(unittest.TestCase):
    def test_existing_running_trigger_is_rejected(self):
        state=load('check_adf_state')
        self.assertEqual(state.check([]),[])
        self.assertEqual(state.check([{'name':'trigger_blob_storage','properties':{'runtimeState':'Stopped'}}]),[])
        self.assertTrue(state.check([{'name':'trigger_blob_storage','properties':{'runtimeState':'Started'}}]))
        self.assertTrue(state.check([{'name':'trigger_blob_storage','properties':{}}]))
    def test_pipeline_and_network_contract(self):
        arm=json.loads(Path(os.environ['VINCULADOR_ADF_ARM']).read_text())
        raw=arm['resources']
        r=raw if isinstance(raw,dict) else {key:next(x for x in raw if x['type']==kind) for key,kind in {'linkedService':'Microsoft.DataFactory/factories/linkedservices','pipeline':'Microsoft.DataFactory/factories/pipelines','trigger':'Microsoft.DataFactory/factories/triggers'}.items()}
        self.assertEqual(r['linkedService']['properties']['typeProperties']['authentication'],'MSI')
        self.assertEqual(r['linkedService']['properties']['connectVia']['referenceName'],'AutoResolveIntegrationRuntime')
        self.assertEqual(r['pipeline']['name'],"[format('{0}/{1}', parameters('dataFactoryName'), 'VINCULADOR_DMAF')]")
        activity=r['pipeline']['properties']['activities'][0]
        self.assertTrue(activity['policy']['secureInput']);self.assertTrue(activity['policy']['secureOutput'])
        trigger=r['trigger']['properties']
        self.assertEqual(trigger['typeProperties']['blobPathBeginsWith'],'/poc-vinculador-trigger-data-factory/blobs/')
        self.assertEqual(trigger['typeProperties']['blobPathEndsWith'],'.json')
        self.assertEqual(trigger['pipelines'][0]['parameters']['fileName'],'@triggerBody().fileName')
        self.assertNotIn('runtimeState',trigger)
        self.assertFalse(arm['parameters']['databricksApproved']['defaultValue'])
        self.assertFalse(arm['parameters']['storageEventsApproved']['defaultValue'])

if __name__=='__main__':unittest.main()

"""Pruebas del contrato de parámetros y de la plantilla ARM compilada."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checker', ROOT / 'scripts/check_parameters.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
SID = '00000000-0000-0000-0000-000000000001'
def rid(kind):
    return f'/subscriptions/{SID}/resourceGroups/caf/providers/{kind}/corporativo'

def foundation():
    zones={'cognitiveServicesAccount':'privatelink.cognitiveservices.azure.com','openAi':'privatelink.openai.azure.com','aiServices':'privatelink.services.ai.azure.com','blob':'privatelink.blob.core.windows.net','vault':'privatelink.vaultcore.azure.net','registry':'privatelink.azurecr.io','cosmosSql':'privatelink.documents.azure.com','searchService':'privatelink.search.windows.net'}
    zone_ids={key:f'/subscriptions/{SID}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/{name}' for key,name in zones.items()}
    return dict(location='eastus', workload='agent', tags={'iniciativa':'pruebas','DataClassification':'Interna','OpsDept':'DTI','UserDept':'GPFEI'}, vnetPrefix='10.123.4.0/24', cafClientPrefixes=['10.121.0.0/24'], privateDnsZoneResourceIds=zone_ids, logAnalyticsWorkspaceId=rid('Microsoft.OperationalInsights/workspaces'), actionGroupId=rid('Microsoft.Insights/actionGroups'), routeTableIds={k:rid('Microsoft.Network/routeTables') for k in ('foundry','containers','appGateway')})

def complete():
    return dict(foundation(), modelsApproved=True, securityApprovalId='CAF-PRUEBA', networkReady=True, defenderCoverageVerified=True, siemDeliveryVerified=True, uploadGateVerified=True, monitorPrefixes=['10.120.1.4/32'], privateServiceAddresses={'vault':['10.123.4.198'], 'cosmos':['10.123.4.202','10.123.4.203']}, activateAgentRuntime=True, deployApplications=True, applicationAuthVerified=True, monitoringReady=True, deployGateway=True, gatewayReady=True, gatewayPrivateIp='10.123.4.254', gatewayHostname='agentes.caf.com', frontendImage='caf.azurecr.io/frontend@sha256:'+'a'*64, backendImage='caf.azurecr.io/backend@sha256:'+'b'*64, models=[dict(name='autorizado', model='modelo-autorizado', version='version-autorizada', sku='Standard', capacity=10)])

class Parameters(unittest.TestCase):
    def test_valid_stages(self):
        self.assertEqual(checker.check(foundation()), [])
        self.assertEqual(checker.check(complete()), [])
    def test_common_governance_required(self):
        self.assertTrue(checker.check(dict(foundation(),tags={'iniciativa':'pruebas'})))
        self.assertTrue(checker.check(dict(complete(),modelsApproved=False)))
        self.assertTrue(checker.check(dict(complete(),securityApprovalId='')))
    def test_exact_partition(self):
        nets=list(checker.subnets('10.123.4.0/24').values())
        self.assertEqual([str(n) for n in nets],['10.123.4.0/25','10.123.4.128/26','10.123.4.192/27','10.123.4.224/27'])
        self.assertEqual(sum(n.num_addresses for n in nets),256)
        self.assertFalse(any(a.overlaps(b) for i,a in enumerate(nets) for b in nets[i+1:]))
    def test_invalid_networks(self):
        for prefix in ['10.123.4.0/23','10.123.4.0/25','10.123.4.1/24','8.8.8.0/24','172.30.0.0/24','172.31.0.0/24','100.64.0.0/24']:
            with self.subTest(prefix=prefix): self.assertTrue(checker.check(dict(foundation(),vnetPrefix=prefix)))
    def test_missing_readiness(self):
        for key in ['defenderCoverageVerified','siemDeliveryVerified','uploadGateVerified','networkReady','activateAgentRuntime','applicationAuthVerified','monitoringReady','gatewayReady','deployApplications']:
            with self.subTest(key=key):
                p=complete();p[key]=False;self.assertTrue(checker.check(p))
    def test_invalid_gateway(self):
        for address in ['10.123.4.224','10.123.4.225','10.123.4.255','10.123.4.200']:
            self.assertTrue(checker.check(dict(complete(),gatewayPrivateIp=address)))
    def test_environment_override_rejected(self):
        self.assertTrue(checker.check(dict(complete(),backendEnv=[{'name':'AZURE_AI_PROJECT_ENDPOINT','value':'https://otro'}])))

    def test_models_images_routes(self):
        for key,value in [('models',[]),('frontendImage','caf.azurecr.io/web:latest'),('routeTableIds',{}),('cafClientPrefixes',['10.123.4.0/24']),('networkReady','true')]:
            self.assertTrue(checker.check(dict(complete(),**{key:value})))

    def test_security_inputs(self):
        for key, value in [('monitorPrefixes', []), ('privateServiceAddresses', {}), ('backendSecretNames', ['APPGATEWAY-TLS']), ('siemEventHubName', 'alone'), ('extraEgress', {'foundry':[{'destination':'0.0.0.0/0','ports':['*'],'justification':''}]})]:
            with self.subTest(key=key): self.assertTrue(checker.check(dict(complete(), **{key:value})))
        self.assertEqual(checker.check(dict(complete(), extraEgress={'containers':[{'destination':'10.122.0.5/32','ports':['443'],'justification':'API aprobada'}]})), [])
        self.assertTrue(checker.check(dict(foundation(), privateDnsZoneResourceIds={'account':rid('Microsoft.Network/privateDnsZones')})))

class Template(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.arm=json.loads(Path(os.environ['ARM_TEMPLATE']).read_text())
        cls.modules={}
        def walk(t):
            resources=t.get('resources',[])
            if isinstance(resources,dict): resources=resources.values()
            for r in resources:
                if r['type']=='Microsoft.Resources/deployments':
                    cls.modules[r['name']]=r
                    yield from walk(r['properties']['template'])
                else: yield r
        cls.resources=list(walk(cls.arm))
    def test_no_platform_duplication(self):
        prohibited=['publicIPAddresses','virtualNetworkPeerings','Microsoft.Insights/components','virtualNetworkGateways','bastionHosts','azureFirewalls','routeTables','workspaces']
        for r in self.resources:
            self.assertNotIn(r['type'].split('/')[-1],prohibited)
        self.assertNotIn('listKeys',json.dumps(self.arm))
    def test_private_and_redundant(self):
        types={r['type']:r for r in self.resources}
        env=types['Microsoft.App/managedEnvironments']['properties']
        self.assertTrue(env['vnetConfiguration']['internal']);self.assertTrue(env['zoneRedundant'])
        self.assertEqual(env['appLogsConfiguration'],{'destination':'azure-monitor'})
        search=types['Microsoft.Search/searchServices']['properties']
        self.assertEqual(search['replicaCount'],3)
        gw=types['Microsoft.Network/applicationGateways']
        self.assertEqual(gw['properties']['autoscaleConfiguration'],{'minCapacity':2,'maxCapacity':3})
        self.assertEqual(gw['zones'],['1','2','3'])
        for r in self.resources:
            if r['type']=='Microsoft.App/containerApps':self.assertEqual(r['properties']['template']['scale'],{'minReplicas':2,'maxReplicas':3})
            if 'publicNetworkAccess' in r.get('properties',{}):self.assertEqual(r['properties']['publicNetworkAccess'].lower(),'disabled')
    def test_identity_and_ingress_boundaries(self):
        apps=[r for r in self.resources if r['type']=='Microsoft.App/containerApps']
        for app in apps:
            ingress=app['properties']['configuration']['ingress']
            self.assertFalse(ingress['allowInsecure'])
            if 'frontend' in app['name']:
                self.assertEqual(ingress['ipSecurityRestrictions'][0]['action'],'Allow')
            else:
                self.assertFalse(ingress['external'])
        roles=[r for r in self.resources if r['type']=='Microsoft.Authorization/roleAssignments']
        forbidden=['8e3af657-a8ff-443c-a75c-2fe8c4bcb635','b24988ac-6180-42a0-ab88-20f7382dd24c']
        for role in roles:
            for role_id in forbidden:self.assertNotIn(role_id,json.dumps(role))

    def test_arm_stage_guards(self):
        contract=self.modules['contratos-despliegue']
        for value in contract['properties']['template']['parameters'].values():self.assertEqual(value['allowedValues'],[True])
        net=self.modules['red-foundry']
        self.assertTrue(any('contracts' in x or 'contratos-despliegue' in x for x in net['dependsOn']))

if __name__=='__main__':unittest.main()

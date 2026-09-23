"""Comprueba parámetros resueltos sin acceder a Azure ni modificar recursos."""
import ipaddress
import json
import re
import sys

compiled = json.load(sys.stdin)
parameters = json.loads(compiled['parametersJson'])['parameters']
template = json.loads(compiled['templateJson'])
values = {k: v['defaultValue'] for k, v in template['parameters'].items() if 'defaultValue' in v}
values.update({k: v['value'] for k, v in parameters.items()})

def require(condition, message):
    if not condition:
        sys.exit(message)

serialized = json.dumps(values)
require(not any(x in serialized for x in ('00000000-0000-0000-0000-000000000000', 'REPLACE-WITH', 'confirm-before-deployment')), 'Completa los valores de ejemplo antes de acceder a Azure.')
require(values['resourceGroupName'].lower() != 'rg-poc-ifis-cr', 'El grupo original no puede ser el destino.')
require(re.fullmatch('[a-z][a-z0-9-]{1,11}', values['namePrefix']), 'namePrefix debe usar letras minúsculas, números y guiones.')
for key in ('hubVnetResourceId', 'existingRouteTableResourceId', 'existingLogAnalyticsWorkspaceResourceId', 'sharedSyntheticStorageAccountResourceId'):
    require(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/[^/]+/[^/]+/[^/]+', values[key]), f'ID inválido: {key}')
zones = values['privateDnsZoneResourceIds']
expected_zones = {'blob':'privatelink.blob.core.windows.net','dfs':'privatelink.dfs.core.windows.net','queue':'privatelink.queue.core.windows.net','table':'privatelink.table.core.windows.net','cognitiveServicesAccount':'privatelink.cognitiveservices.azure.com','openAi':'privatelink.openai.azure.com','Sql':'privatelink.documents.azure.com','sites':'privatelink.azurewebsites.net','dataFactory':'privatelink.datafactory.azure.net','portal':'privatelink.adf.azure.com','databricks_ui_api':'privatelink.azuredatabricks.net','browser_authentication':'privatelink.azuredatabricks.net'}
require(set(zones) == set(expected_zones), 'Definir todas las zonas DNS privadas de IFISCAF.')
for service, zone_id in zones.items():
    require(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/[^/]+', zone_id, re.I), f'ID de zona DNS inválido: {service}')
    require(zone_id.lower().endswith('/' + expected_zones[service].lower()), f'Nombre de zona DNS incorrecto: {service}')
try:
    vnets = [ipaddress.IPv4Network(x) for x in values['vnetAddressPrefixes']]
    subnets = {k: ipaddress.IPv4Network(v) for k, v in values['subnetPrefixes'].items()}
except ValueError as error:
    sys.exit(str(error))
for name, subnet in subnets.items():
    require(any(subnet.subnet_of(vnet) for vnet in vnets), f'{name} está fuera de la VNet.')
    require(subnet.prefixlen <= 26, f'{name} debe ser /26 o mayor.')
for i, (name, subnet) in enumerate(subnets.items()):
    for other_name, other in list(subnets.items())[i + 1:]:
        require(not subnet.overlaps(other), f'Solapamiento: {name} y {other_name}.')
require(values['functionOpenAiDeploymentName'] in [m['name'] for m in values['openAiModelDeployments']], 'El modelo configurado en Functions no existe en openAiModelDeployments.')
require(all(m['capacity'] > 0 for m in values['openAiModelDeployments']), 'La capacidad debe ser positiva.')
print(json.dumps(values))

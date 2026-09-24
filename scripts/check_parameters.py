#!/usr/bin/env python3
"""Valida el contrato local de Smart Review sin imprimir configuración segura."""
import ipaddress
import json
import re
import sys
from pathlib import Path

PRIVATE=[ipaddress.ip_network(n) for n in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16')]

def check(p):
    errors=[]
    def require(ok,message):
        if not ok: errors.append(message)
    # Nunca devolver los valores de objetos secure.
    public={k:v for k,v in p.items() if k not in ('functionApplicationSettings','frontendApplicationSettings')}
    require(not re.search(r'PENDIENTE|REPLACE|REEMPLAZAR|00000000-0000-0000-0000-000000000000',json.dumps(public),re.I),'Completar marcadores corporativos.')
    for key in ('iniciativa','DataClassification','OpsDept','UserDept'): require(bool(p.get('tags',{}).get(key)),f'Etiqueta {key} requerida.')
    require(p.get('tags',{}).get('OpsDept')=='DTI','Etiqueta OpsDept debe ser DTI.')
    for key in ('functionAppName','functionPlanName','frontendAppName','frontendPlanName','applicationInsightsName','cosmosAccountName','openAiAccountName','documentIntelligenceAccountName','keyVaultName'):
        require(bool(p.get(key)),f'{key}: nombre nuevo requerido.')
    require(bool(re.fullmatch(r'[a-z0-9]{3,24}',p.get('hostStorageAccountName',''))),'Nombre Storage del host inválido.')
    for key,kind in [('routeTableResourceId','Microsoft.Network/routeTables'),('logAnalyticsWorkspaceResourceId','Microsoft.OperationalInsights/workspaces')]:
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/'+re.escape(kind)+r'/[^/]+',p.get(key,''))),f'{key}: ID completo requerido.')
    zones=p.get('privateDnsZoneResourceIds',{})
    require(set(zones)=={'blob','queue','table','sites','cosmosSql','openAi','cognitiveServicesAccount','keyVault'},'Definir todas las zonas DNS privadas de Smart Review.')
    for service,zone_id in zones.items():
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/[^/]+',zone_id,re.I)),f'Zona DNS de {service}: usar ID completo en RG-PRIVATEDNS-PR.')
    if p.get('actionGroupResourceId'):
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Insights/actionGroups/[^/]+',p['actionGroupResourceId'])),'Action Group: ID inválido.')
    require(bool(p.get('siemAuthorizationRuleId')) and bool(p.get('siemEventHubName')),'SIEM: ID y nombre son obligatorios.')
    require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.EventHub/namespaces/[^/]+/authorizationRules/[^/]+',p.get('siemAuthorizationRuleId',''))),'SIEM: ID de regla del namespace inválido.')
    nets={}
    try:
        vnets=[ipaddress.IPv4Network(n,strict=True) for n in p['vnetAddressPrefixes']]
        require(bool(vnets) and all(any(n.subnet_of(v) for v in PRIVATE) for n in vnets),'VNet debe utilizar RFC1918.')
        nets={k:ipaddress.IPv4Network(v,strict=True) for k,v in p['subnetPrefixes'].items()}
        require(set(nets)=={'privateEndpoints','functionsIntegration','frontendIntegration'},'Definir las tres subredes de Smart Review.')
        for k,n in nets.items():
            require(any(n.subnet_of(v) for v in vnets),f'{k}: fuera de VNet.')
            require(n.prefixlen<=(27 if k=='privateEndpoints' else 26),f'{k}: espacio insuficiente para esta base.')
        for name,left in nets.items():
            for other,right in nets.items():
                if name < other: require(not left.overlaps(right),'Subredes solapadas.')
    except (ValueError,KeyError,TypeError): errors.append('CIDR inválido.')
    for key in ('apiClientPrefixes','operatorPrefixes','monitorPrefixes','functionPrivateIps','frontendPrivateIps','cosmosPrivateIps'):
        values=p.get(key,[])
        for value in values:
            try:
                n=ipaddress.IPv4Network(value,strict=True)
                require(any(n.subnet_of(v) for v in PRIVATE),f'{key}: red privada requerida.')
                if key in ('functionPrivateIps','frontendPrivateIps','cosmosPrivateIps'):require(n.prefixlen==32 and '/' not in value,f'{key}: IP individual sin máscara requerida.')
                if key in ('functionPrivateIps','frontendPrivateIps','cosmosPrivateIps') and 'privateEndpoints' in nets:
                    pe=nets['privateEndpoints'];require(n.subnet_of(pe) and int(n.network_address)-int(pe.network_address)>=4 and n.network_address!=pe.broadcast_address,'IP Function fuera de endpoints o reservada.')
            except (ValueError,TypeError):errors.append(f'{key}: IP/CIDR inválido.')
    for flag in ('activateFunctionApp','activateFrontendApp','inventoryVerified','networkVerified','defenderVerified','siemVerified','monitoringPrivateLinkVerified','applicationVerified','processesUntrustedFiles','fileScanningVerified','hostUsesTables','hostUsesBlobTriggers','hostUsesDurableStorage'):
        require(type(p.get(flag,False)) is bool,f'{flag}: booleano requerido.')
    if p.get('activateFunctionApp'):
        for flag in ('inventoryVerified','networkVerified','defenderVerified','siemVerified','monitoringPrivateLinkVerified','applicationVerified'):
            require(p.get(flag) is True,f'Activación requiere {flag}.')
        for key in ('securityApprovalId','allowedPrincipalIds','functionPrivateIps','apiClientPrefixes','monitorPrefixes','actionGroupResourceId'):
            require(bool(p.get(key)),f'Activación requiere {key}.')
        require(not p.get('processesUntrustedFiles', True) or p.get('fileScanningVerified') is True,'Verificar análisis y bloqueo de archivos no confiables antes de activar.')
    ids=p.get('allowedPrincipalIds',[])
    require(len(ids)<=13 and len(ids)==len(set(ids)),'Identidades duplicadas o lista demasiado larga.')
    for value in ids:require(bool(re.fullmatch(r'[0-9a-fA-F-]{36}',value)),'Object ID de identidad inválido.')
    for key in p.get('functionApplicationSettings',{}):
        require(not key.lower().startswith('azurewebjobsstorage') and key.lower() not in ('functions_worker_runtime','functions_extension_version','applicationinsights_connection_string'),'applicationSettings no puede redefinir conexiones del host o runtime.')
    require(all(isinstance(v,str) and v.startswith('https://') and '*' not in v for v in p.get('allowedOrigins',[])),'CORS debe usar orígenes HTTPS explícitos.')
    require(len(p.get('extraEgress',[]))<=100,'Máximo 100 excepciones de salida.')
    for rule in p.get('extraEgress',[]):
        require(rule.get('purpose')=='functionsIntegration','Excepción solo permitida en integración Functions.')
        require(bool(rule.get('justification','').strip()) and len(rule.get('justification',''))<=140,'Excepción requiere justificación de hasta 140 caracteres.')
        try:require(ipaddress.IPv4Network(rule.get('destination',''),strict=True).prefixlen>=24,'Destino /24 o más específico requerido.')
        except ValueError:errors.append('Destino IPv4/CIDR explícito requerido.')
        require(bool(rule.get('ports')) and all(isinstance(v,str) and v.isdigit() and 1<=int(v)<=65535 for v in rule.get('ports',[])),'Puertos TCP individuales requeridos.')
    require(p.get('location','eastus')=='eastus','La base acordada utiliza East US.')
    require(p.get('hostStorageAccountName')!=p.get('businessStorageAccountName'),'Separar host y documentos.')
    require(bool(re.fullmatch(r'[a-z0-9]{3,24}',p.get('businessStorageAccountName',''))),'Nombre Storage de documentos inválido.')
    require(len(p.get('vnetAddressPrefixes',[]))==1 and p['vnetAddressPrefixes'][0].endswith('/24'),'Asignar una única VNet /24 aprobada por IPAM.')
    all_private_ips=p.get('functionPrivateIps',[])+p.get('frontendPrivateIps',[])+p.get('cosmosPrivateIps',[])
    require(len(all_private_ips)==len(set(all_private_ips)),'Function, frontend y Cosmos deben tener IP distintas.')
    models=p.get('models',[])
    require(not models or p.get('modelsApproved') is True,'Confirmar explícitamente modelos y cuotas.')
    require(len({m.get('name') for m in models})==len(models),'Alias de modelos duplicados.')
    for m in models:
        require(all(isinstance(m.get(k),str) and m[k].strip() for k in ('name','model','version','sku')) and type(m.get('capacity')) is int and m['capacity']>0,'Modelo requiere alias, nombre, versión, modalidad y capacidad positiva.')
    for flag in ('batchEnabled','modelsApproved'):
        require(type(p.get(flag,False)) is bool,f'{flag}: booleano requerido.')
    if p.get('activateFunctionApp'):
        require(bool(models) and bool(p.get('cosmosPrivateIps')),'Activación requiere modelos e IP reales de Cosmos.')
        require(p.get('batchEnabled') is True or not any('Batch' in m.get('sku','') for m in models),'Modelos Batch requieren permisos Batch.')
    if p.get('activateFrontendApp'):
        for flag in ('inventoryVerified','networkVerified','siemVerified','applicationVerified'):
            require(p.get(flag) is True,f'Activación del frontend requiere {flag}.')
        for key in ('securityApprovalId','allowedPrincipalIds','frontendPrivateIps','apiClientPrefixes'):
            require(bool(p.get(key)),f'Activación del frontend requiere {key}.')
    require(len(p.get('secretNames',[]))==len(set(p.get('secretNames',[]))) and all(re.fullmatch(r'[A-Za-z0-9-]{1,127}',v) for v in p.get('secretNames',[])),'Nombres de secretos inválidos o duplicados.')
    return errors

if __name__=='__main__':
    try:
        d=json.loads(Path(sys.argv[1]).read_text());errors=check({k:v['value'] for k,v in d['parameters'].items()})
    except (OSError,ValueError,KeyError,IndexError,TypeError,AttributeError):errors=['Archivo de parámetros inválido; no se muestran sus valores.']
    print('\n'.join(errors) if errors else 'Contrato local válido; pendiente validar Azure y dependencias reales.')
    sys.exit(bool(errors))

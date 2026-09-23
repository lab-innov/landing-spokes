#!/usr/bin/env python3
"""Valida el contrato local de ECOCAF sin imprimir valores de configuración de aplicación."""
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
    # Nunca devolver los valores del objeto secure applicationSettings.
    public={k:v for k,v in p.items() if k not in ('applicationSettings','frontendApplicationSettings')}
    require(not re.search(r'PENDIENTE|REPLACE|REEMPLAZAR|00000000-0000-0000-0000-000000000000',json.dumps(public),re.I),'Completar marcadores corporativos.')
    for key in ('iniciativa','DataClassification','OpsDept','UserDept'): require(bool(p.get('tags',{}).get(key)),f'Etiqueta {key} requerida.')
    require(p.get('tags',{}).get('OpsDept')=='DTI','Etiqueta OpsDept debe ser DTI.')
    for key,old in [('functionAppName','azfun-poc-eco-caf-cr'),('planName','appsp-poc-eco-caf-cr'),('storageAccountName','rgpocecocafcraf57'),('frontendAppName','app-idatafactory-cr'),('frontendPlanName','appsp-poc-idatafactory-cr'),('businessStorageAccountName','sapocidatafactorycr'),('cosmosAccountName','cd-poc-idatafactory-cr'),('openAiAccountName','oai-poc-idatafactory-cr'),('documentIntelligenceAccountName','di-poc-idatafactory-cr')]:
        require(bool(p.get(key)) and p[key].lower()!=old,f'{key}: usar nombre nuevo para migración paralela.')
    for key in ('storageAccountName','businessStorageAccountName'):
        require(bool(re.fullmatch(r'[a-z0-9]{3,24}',p.get(key,''))),f'{key}: nombre Storage inválido.')
    require(p.get('storageAccountName')!=p.get('businessStorageAccountName'),'Storage de host y negocio deben ser diferentes.')
    for key,kind in [('routeTableResourceId','Microsoft.Network/routeTables'),('logAnalyticsWorkspaceResourceId','Microsoft.OperationalInsights/workspaces')]:
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/'+re.escape(kind)+r'/[^/]+',p.get(key,''))),f'{key}: ID completo requerido.')
    zones=p.get('privateDnsZoneResourceIds',{})
    require(set(zones)=={'blob','dfs','queue','table','sites','cosmosSql','cognitiveServicesAccount','openAi'},'Definir las ocho zonas DNS privadas de ECOCAF.')
    expected_zones={'blob':'privatelink.blob.core.windows.net','dfs':'privatelink.dfs.core.windows.net','queue':'privatelink.queue.core.windows.net','table':'privatelink.table.core.windows.net','sites':'privatelink.azurewebsites.net','cosmosSql':'privatelink.documents.azure.com','cognitiveServicesAccount':'privatelink.cognitiveservices.azure.com','openAi':'privatelink.openai.azure.com'}
    for service,zone_id in zones.items():
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/RG-PRIVATEDNS-PR/providers/Microsoft.Network/privateDnsZones/[^/]+',zone_id,re.I)),f'Zona DNS de {service}: usar ID completo en RG-PRIVATEDNS-PR.')
        require(zone_id.lower().endswith('/'+expected_zones.get(service,'' ).lower()),f'Zona DNS de {service}: nombre privado incorrecto.')
    if p.get('actionGroupResourceId'):
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Insights/actionGroups/[^/]+',p['actionGroupResourceId'])),'Action Group: ID inválido.')
    require(bool(p.get('siemAuthorizationRuleId'))==bool(p.get('siemEventHubName')),'SIEM: proporcionar ID y nombre juntos.')
    if p.get('siemAuthorizationRuleId'):
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.EventHub/namespaces/[^/]+/authorizationRules/[^/]+',p['siemAuthorizationRuleId'])),'SIEM: ID de regla del namespace inválido.')
    nets={}
    try:
        vnets=[ipaddress.IPv4Network(n,strict=True) for n in p['vnetAddressPrefixes']]
        require(bool(vnets) and all(any(n.subnet_of(v) for v in PRIVATE) for n in vnets),'VNet debe utilizar RFC1918.')
        nets={k:ipaddress.IPv4Network(v,strict=True) for k,v in p['subnetPrefixes'].items()}
        require(set(nets)=={'privateEndpoints','functionsIntegration','frontendIntegration'},'Definir las tres subredes ECOCAF.')
        for k,n in nets.items():
            require(any(n.subnet_of(v) for v in vnets),f'{k}: fuera de VNet.')
            require(n.prefixlen<=(27 if k=='privateEndpoints' else 26),f'{k}: espacio insuficiente para esta base.')
        for left,right in [('privateEndpoints','functionsIntegration'),('privateEndpoints','frontendIntegration'),('functionsIntegration','frontendIntegration')]:
            require(not nets[left].overlaps(nets[right]),f'Subredes {left}/{right} solapadas.')
    except (ValueError,KeyError,TypeError): errors.append('CIDR inválido.')
    for key in ('apiClientPrefixes','operatorPrefixes','monitorPrefixes','functionPrivateIps','frontendPrivateIps'):
        values=p.get(key,[])
        for value in values:
            try:
                n=ipaddress.IPv4Network(value,strict=True)
                require(any(n.subnet_of(v) for v in PRIVATE),f'{key}: red privada requerida.')
                if key in ('functionPrivateIps','frontendPrivateIps'):require(n.prefixlen==32,f'{key}: IP individual requerida.')
                if key in ('functionPrivateIps','frontendPrivateIps') and 'privateEndpoints' in nets:
                    pe=nets['privateEndpoints'];require(n.subnet_of(pe) and int(n.network_address)-int(pe.network_address)>=4 and n.network_address!=pe.broadcast_address,f'{key}: IP fuera de endpoints o reservada.')
            except (ValueError,TypeError):errors.append(f'{key}: IP/CIDR inválido.')
    for flag in ('activateFunctionApp','activateFrontend','modelsApproved','commonServicesVerified','identityMigrationVerified','inventoryVerified','networkVerified','defenderVerified','siemVerified','applicationVerified','frontendApplicationVerified','processesUntrustedFiles','fileScanningVerified','hostUsesTables','hostUsesBlobTriggers','hostUsesDurableStorage'):
        require(type(p.get(flag,False)) is bool,f'{flag}: booleano requerido.')
    if p.get('activateFunctionApp'):
        for flag in ('inventoryVerified','networkVerified','defenderVerified','siemVerified','applicationVerified'):
            require(p.get(flag) is True,f'Activación requiere {flag}.')
        for key in ('securityApprovalId','allowedPrincipalIds','functionPrivateIps','apiClientPrefixes','monitorPrefixes','actionGroupResourceId'):
            require(bool(p.get(key)),f'Activación requiere {key}.')
        for key in ('modelsApproved','commonServicesVerified','identityMigrationVerified'):
            require(p.get(key) is True,f'Activación requiere {key}.')
        require(bool(p.get('models')),'Activación requiere al menos un modelo aprobado.')
        require(not p.get('processesUntrustedFiles') or p.get('fileScanningVerified') is True,'Verificar análisis y bloqueo de archivos no confiables antes de activar.')
    if p.get('activateFrontend'):
        require(p.get('activateFunctionApp') is True,'Frontend requiere backend activado.')
        require(p.get('frontendApplicationVerified') is True,'Frontend requiere frontendApplicationVerified.')
        for key in ('frontendAllowedPrincipalIds','frontendPrivateIps'):
            require(bool(p.get(key)),f'Frontend requiere {key}.')
        require('MICROSOFT_PROVIDER_AUTHENTICATION_SECRET' in p.get('frontendApplicationSettings',{}),'Frontend requiere secreto Easy Auth suministrado fuera de Git.')
    ids=p.get('allowedPrincipalIds',[])
    require(len(ids)<=13 and len(ids)==len(set(ids)),'Identidades duplicadas o lista demasiado larga.')
    for value in ids:require(bool(re.fullmatch(r'[0-9a-fA-F-]{36}',value)),'Object ID de identidad inválido.')
    frontend_ids=p.get('frontendAllowedPrincipalIds',[])
    require(len(frontend_ids)<=50 and len(frontend_ids)==len(set(frontend_ids)),'Identidades frontend duplicadas o lista demasiado larga.')
    for value in frontend_ids:require(bool(re.fullmatch(r'[0-9a-fA-F-]{36}',value)),'Object ID frontend inválido.')
    for key in p.get('applicationSettings',{}):
        lowered=key.lower()
        require(not lowered.startswith('azurewebjobsstorage') and not lowered.endswith('_key') and not lowered.endswith('_connection_string') and lowered not in ('functions_worker_runtime','functions_extension_version','applicationinsights_connection_string'),'applicationSettings no puede redefinir conexiones, claves o runtime.')
    models=p.get('models',[])
    require(not models or p.get('modelsApproved') is True,'Los modelos requieren aprobación explícita.')
    for model in models:
        require(all(model.get(k) for k in ('name','model','version','sku')) and isinstance(model.get('capacity'),int) and model['capacity']>0,'Modelo incompleto o capacidad inválida.')
    require(bool(p.get('openAiApiVersion')),'Versión API de OpenAI requerida.')
    urls=p.get('commonServiceUrls',{})
    require(set(urls)=={'audits','notifications','pdfConverter'},'Definir las tres APIs comunes.')
    require(all(isinstance(v,str) and v.startswith('https://') and '*' not in v for v in urls.values()),'APIs comunes deben usar URLs HTTPS explícitas.')
    require(all(isinstance(v,str) and v.startswith('https://') and '*' not in v for v in p.get('allowedOrigins',[])),'CORS debe usar orígenes HTTPS explícitos.')
    require(len(p.get('extraEgress',[]))<=100,'Máximo 100 excepciones de salida.')
    for rule in p.get('extraEgress',[]):
        require(rule.get('purpose') in ('functionsIntegration','frontendIntegration'),'Excepción solo permitida en integración Functions o frontend.')
        require(bool(rule.get('justification','').strip()) and len(rule.get('justification',''))<=140,'Excepción requiere justificación de hasta 140 caracteres.')
        try:require(ipaddress.IPv4Network(rule.get('destination',''),strict=True).prefixlen>=24,'Destino /24 o más específico requerido.')
        except ValueError:errors.append('Destino IPv4/CIDR explícito requerido.')
        require(bool(rule.get('ports')) and all(isinstance(v,str) and v.isdigit() and 1<=int(v)<=65535 for v in rule.get('ports',[])),'Puertos TCP individuales requeridos.')
    return errors

if __name__=='__main__':
    try:
        d=json.loads(Path(sys.argv[1]).read_text());errors=check({k:v['value'] for k,v in d['parameters'].items()})
    except (OSError,ValueError,KeyError,IndexError,TypeError,AttributeError):errors=['Archivo de parámetros inválido; no se muestran sus valores.']
    print('\n'.join(errors) if errors else 'Contrato local válido; pendiente validar Azure y dependencias reales.')
    sys.exit(bool(errors))

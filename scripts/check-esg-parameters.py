#!/usr/bin/env python3
"""Valida parámetros compilados; no acredita estado operativo de Azure."""
import ipaddress
import json
import re
import sys
from pathlib import Path

PRIVATE = [ipaddress.ip_network(n) for n in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16')]

def check(p):
    errors=[]
    def require(ok,msg):
        if not ok: errors.append(msg)
    require(not re.search(r'REPLACE|REEMPLAZAR|00000000-0000-0000-0000-000000000000|confirm-before',json.dumps(p),re.I),'Sustituir los marcadores y confirmar clasificación.')
    for tag in ('iniciativa','DataClassification','OpsDept','UserDept'):
        require(bool(p.get('tags',{}).get(tag)),f'Etiqueta obligatoria: {tag}.')
    require(p.get('tags',{}).get('OpsDept')=='DTI','OpsDept debe ser DTI.')
    require(p.get('resourceGroupName','').lower() != 'rg-poc-esg-cr','Preservar el RG original; la migración es paralela.')
    nets={}
    try:
        vnets=[ipaddress.IPv4Network(n,strict=True) for n in p['vnetAddressPrefixes']]
        require(bool(vnets) and all(any(n.subnet_of(v) for v in PRIVATE) for n in vnets),'VNet debe utilizar RFC1918.')
        nets={k:ipaddress.IPv4Network(v,strict=True) for k,v in p['subnetPrefixes'].items()}
        expected={'privateEndpoints':27,'foundryAgents':24,'functionsIntegration':26,'databricksPublic':26,'databricksPrivate':26}
        require(set(nets)==set(expected),'Deben definirse las cinco subredes ESG.')
        for k,n in nets.items():
            require(any(n.subnet_of(v) for v in vnets),f'{k}: fuera de VNet.')
            require(n.prefixlen<=expected[k],f'{k}: subred insuficiente para esta base.')
        values=list(nets.values())
        require(not any(a.overlaps(b) for i,a in enumerate(values) for b in values[i+1:]),'Subredes solapadas.')
    except (KeyError,ValueError,TypeError): errors.append('CIDR o contrato de subred inválido.')
    for key in ('apiClientPrefixes','operatorPrefixes','monitorPrefixes','cosmosPrivateIps','functionPrivateIps'):
        values=p.get(key,[])
        for value in values:
            try:
                n=ipaddress.IPv4Network(value,strict=True)
                require(any(n.subnet_of(v) for v in PRIVATE),f'{key}: usar IPv4 privada.')
                if key.endswith('PrivateIps'): require(n.prefixlen==32,f'{key}: usar IP individual.')
                if key.endswith('PrivateIps') and 'privateEndpoints' in nets:
                    pe=nets['privateEndpoints'];require(n.subnet_of(pe) and int(n.network_address)-int(pe.network_address)>=4 and n.network_address!=pe.broadcast_address,f'{key}: IP fuera de endpoints o reservada.')
            except (ValueError,TypeError): errors.append(f'{key}: dirección inválida.')
    for flag in ('activateWorkload','networkVerified','defenderVerified','siemVerified','applicationVerified','uploadGateVerified','modelsApproved','functionUsesBlobTriggers','functionUsesDurableStorage','deployGroundingWithBing','scanUploads'):
        require(type(p.get(flag,False)) is bool,f'{flag}: debe ser booleano.')
    ids=p.get('functionAllowedPrincipalIds',[])
    require(len(ids)<=13 and len(ids)==len(set(ids)),'Lista de identidades duplicada o demasiado larga.')
    for value in ids: require(bool(re.fullmatch(r'[0-9a-fA-F-]{36}',value)),'Object ID de identidad inválido.')
    if p.get('activateWorkload'):
        for flag in ('networkVerified','defenderVerified','siemVerified','applicationVerified'):
            require(p.get(flag) is True,f'Activación requiere {flag}.')
        for key in ('actionGroupResourceId','securityApprovalId','functionAllowedPrincipalIds','functionPrivateIps','cosmosPrivateIps','apiClientPrefixes','monitorPrefixes'):
            require(bool(p.get(key)),f'Activación requiere {key}.')
        require(not p.get('scanUploads',True) or p.get('uploadGateVerified') is True,'Validar bloqueo de archivos no analizados antes de activar.')
    if p.get('deployGroundingWithBing'):
        require(bool(p.get('groundingComplianceExceptionId')),'Grounding requiere excepción real.')
    for key in ('foundryModelDeployments','openAiModelDeployments'):
        if p.get(key): require(p.get('modelsApproved') is True,'Modelos requieren confirmación explícita.')
        for model in p.get(key,[]):
            require(all(model.get(k) for k in ('name','model','version','sku','raiPolicy')) and type(model.get('capacity')) is int and model['capacity']>0,'Contrato de modelo incompleto.')
    if p.get('siemAuthorizationRuleId'):
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.EventHub/namespaces/[^/]+/authorizationRules/[^/]+', p['siemAuthorizationRuleId'])), 'ID de regla del namespace Event Hub inválido.')
    for key, kind in [('existingRouteTableResourceId','Microsoft.Network/routeTables'), ('existingLogAnalyticsWorkspaceResourceId','Microsoft.OperationalInsights/workspaces')]:
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/'+re.escape(kind)+r'/[^/]+', p.get(key,''))), f'{key}: ID completo requerido.')
    zones=p.get('privateDnsZoneResourceIds',{})
    require({'blob','queue','table','account','Sql','sites','dataFactory','portal','databricks_ui_api','browser_authentication'}==set(zones),'Definir todas las zonas DNS privadas ESG.')
    if p.get('actionGroupResourceId'):
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Insights/actionGroups/[^/]+',p['actionGroupResourceId'])), 'ID de Action Group inválido.')
    require(bool(p.get('siemAuthorizationRuleId'))==bool(p.get('siemEventHubName')),'SIEM: ID y nombre deben proporcionarse juntos.')
    for rule in p.get('extraEgress',[]):
        require(rule.get('purpose') in ('foundryAgents','functionsIntegration'),'Excepciones solo para subredes propias; Databricks se coordina con CAF.')
        require(bool(rule.get('justification','').strip()) and len(rule.get('justification',''))<=140,'Excepción requiere justificación de hasta 140 caracteres.')
        try: require(ipaddress.IPv4Network(rule.get('destination',''),strict=True).prefixlen>=24,'Destino debe ser /24 o más específico.')
        except ValueError: errors.append('Destino explícito IPv4/CIDR requerido.')
        require(bool(rule.get('ports')) and all(isinstance(v,str) and v.isdigit() and 1<=int(v)<=65535 for v in rule.get('ports',[])),'Excepción requiere puertos TCP individuales.')
    require(len(p.get('extraEgress',[]))<=100,'Máximo 100 excepciones.')
    return errors

if __name__=='__main__':
    try:
        doc=json.loads(Path(sys.argv[1]).read_text())
        errors=check({k:v['value'] for k,v in doc['parameters'].items()})
    except (ValueError,KeyError,IndexError,TypeError) as exc: errors=[f'Parámetros inválidos: {exc}']
    print('\n'.join(errors) if errors else 'Contrato local correcto; pendiente validación Azure.')
    sys.exit(bool(errors))

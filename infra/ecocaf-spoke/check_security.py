#!/usr/bin/env python3
"""Preflight de solo lectura de los recursos confirmados ECOCAF. No inspecciona secretos."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

def get(path):
    response=subprocess.run(['az','rest','--method','get','--url','https://management.azure.com'+path,'--output','json','--only-show-errors'],capture_output=True,text=True)
    if response.returncode:raise RuntimeError('Lectura Azure incompleta; revisar permisos y sesión.')
    return json.loads(response.stdout)

def assess(plans,storages):
    errors=[]
    for name in ('CloudPosture','AppServices','AI','CosmosDbs'):
        if plans.get(name,{}).get('pricingTier')!='Standard':errors.append(f'Plan {name} Standard pendiente de confirmar.')
    if 'isEnabled' in storages:storages={'host':storages}
    for name,configuration in storages.items():
        if configuration.get('isEnabled') is not True:errors.append(f'Defender del Storage {name} no habilitado.')
    return errors

def private_ips(rg,resource_ids):
    errors=[];result={name:[] for name in resource_ids}
    for pe in get(rg+'/providers/Microsoft.Network/privateEndpoints?api-version=2024-05-01')['value']:
        props=pe['properties'];connections=props.get('privateLinkServiceConnections',[])+props.get('manualPrivateLinkServiceConnections',[])
        for name,resource_id in resource_ids.items():
            matched=[c['properties'] for c in connections if c['properties'].get('privateLinkServiceId','').lower()==resource_id.lower()]
            if not matched:continue
            if not all(c.get('privateLinkServiceConnectionState',{}).get('status')=='Approved' for c in matched):errors.append(f'Endpoint {name} no aprobado.');continue
            for nic in props.get('networkInterfaces',[]):
                result[name].extend(c['properties']['privateIPAddress'] for c in get(nic['id']+'?api-version=2024-05-01')['properties']['ipConfigurations'])
    for name,ips in result.items():
        if not ips:errors.append(f'No se encontraron IP de endpoint {name} aprobado.')
        result[name]=sorted(set(ips))
    return result,errors

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--resources',required=True,help='Valor JSON de securityResourceIds.')
    args=parser.parse_args();ids=json.loads(Path(args.resources).read_text());scopes=set()
    kinds={'hostStorage':'Microsoft.Storage/storageAccounts','businessStorage':'Microsoft.Storage/storageAccounts','functionApp':'Microsoft.Web/sites','frontend':'Microsoft.Web/sites','cosmos':'Microsoft.DocumentDB/databaseAccounts','openAi':'Microsoft.CognitiveServices/accounts','documentIntelligence':'Microsoft.CognitiveServices/accounts'}
    for name,kind in kinds.items():
        m=re.fullmatch(r'(/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/[^/]+)/providers/'+re.escape(kind)+r'/[^/]+',ids.get(name,''))
        if not m:raise ValueError('IDs de recursos inválidos.')
        scopes.add((m[1],m[2]))
    if len(scopes)!=1:raise ValueError('Indicar recursos del mismo RG y suscripción de destino.')
    rg,sid=scopes.pop()
    plans={v['name']:v['properties'] for v in get(f'/subscriptions/{sid}/providers/Microsoft.Security/pricings?api-version=2024-01-01')['value']}
    storages={name:get(ids[name]+'/providers/Microsoft.Security/defenderForStorageSettings/current?api-version=2025-06-01')['properties'] for name in ('hostStorage','businessStorage')}
    errors=assess(plans,storages)
    ips,endpoint_errors=private_ips(rg,{'functionApp':ids['functionApp'],'frontend':ids['frontend']});errors.extend(endpoint_errors)
    print(json.dumps({'functionPrivateIps':ips['functionApp'],'frontendPrivateIps':ips['frontend'],'storageConfigurations':storages,'issues':errors,'configurationChecked':not errors,'pending':'No acredita recepción SIEM, detección efectiva, migración de datos/código ni contratos de APIs comunes.'},indent=2,ensure_ascii=False));return bool(errors)

if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,RuntimeError):print('Preflight incompleto; verificar IDs, permisos y sesión. No se muestran respuestas de error.',file=sys.stderr);sys.exit(1)

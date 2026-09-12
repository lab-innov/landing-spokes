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

def assess(plans,host):
    errors=[]
    for name in ('CloudPosture','AppServices'):
        if plans.get(name,{}).get('pricingTier')!='Standard':errors.append(f'Plan {name} Standard pendiente de confirmar.')
    if host.get('isEnabled') is not True:errors.append('Defender del Storage de host no habilitado.')
    return errors

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--resources',required=True,help='Valor JSON de securityResourceIds.')
    args=parser.parse_args();ids=json.loads(Path(args.resources).read_text());scopes=set()
    for name,kind in [('hostStorage','Microsoft.Storage/storageAccounts'),('functionApp','Microsoft.Web/sites')]:
        m=re.fullmatch(r'(/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/[^/]+)/providers/'+re.escape(kind)+r'/[^/]+',ids.get(name,''))
        if not m:raise ValueError('IDs de recursos inválidos.')
        scopes.add((m[1],m[2]))
    if len(scopes)!=1:raise ValueError('Indicar recursos del mismo RG y suscripción de destino.')
    rg,sid=scopes.pop()
    plans={v['name']:v['properties'] for v in get(f'/subscriptions/{sid}/providers/Microsoft.Security/pricings?api-version=2024-01-01')['value']}
    storage=get(ids['hostStorage']+'/providers/Microsoft.Security/defenderForStorageSettings/current?api-version=2025-06-01')['properties']
    errors=assess(plans,storage);ips=[]
    for pe in get(rg+'/providers/Microsoft.Network/privateEndpoints?api-version=2024-05-01')['value']:
        props=pe['properties'];connections=props.get('privateLinkServiceConnections',[])+props.get('manualPrivateLinkServiceConnections',[])
        matched=[c['properties'] for c in connections if c['properties'].get('privateLinkServiceId','').lower()==ids['functionApp'].lower()]
        if not matched:continue
        if not all(c.get('privateLinkServiceConnectionState',{}).get('status')=='Approved' for c in matched):errors.append('Endpoint Function no aprobado.');continue
        for nic in props.get('networkInterfaces',[]):
            ips.extend(c['properties']['privateIPAddress'] for c in get(nic['id']+'?api-version=2024-05-01')['properties']['ipConfigurations'])
    if not ips:errors.append('No se encontraron IP de endpoint Function aprobado.')
    print(json.dumps({'functionPrivateIps':sorted(set(ips)),'hostStorageConfiguration':storage,'issues':errors,'configurationChecked':not errors,'pending':'No acredita recepción SIEM, detección efectiva ni cobertura de datos/servicios externos. Completar inventario y análisis de archivos en su almacenamiento real.'},indent=2,ensure_ascii=False));return bool(errors)

if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,RuntimeError):print('Preflight incompleto; verificar IDs, permisos y sesión. No se muestran respuestas de error.',file=sys.stderr);sys.exit(1)

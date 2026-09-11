#!/usr/bin/env python3
"""Lee configuración Defender e IP de endpoints ESG; no modifica Azure."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


def get(path):
    result=subprocess.run(['az','rest','--method','get','--url','https://management.azure.com'+path,'--output','json','--only-show-errors'],capture_output=True,text=True)
    if result.returncode: raise RuntimeError('No se pudo consultar '+path.split('?')[0])
    return json.loads(result.stdout)


def assess(plans,stores,scan=True):
    errors=[]
    for name in ('CloudPosture','AppServices','CosmosDbs','AI'):
        if plans.get(name,{}).get('pricingTier')!='Standard': errors.append(f'Cobertura {name} Standard pendiente.')
    for name,settings in stores.items():
        if settings.get('isEnabled') is not True: errors.append(f'{name}: Defender for Storage no habilitado.')
    if scan:
        scanning=stores.get('workloadStorage',{}).get('malwareScanning',{}).get('onUpload',{})
        if scanning.get('isEnabled') is not True: errors.append('Análisis de archivos ESG no habilitado.')
        cap=scanning.get('capGBPerMonth')
        if type(cap) is not int or (cap!=-1 and cap<=0): errors.append('Límite de análisis pendiente de verificar.')
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resources',required=True,help='Valor JSON del output securityResourceIds.')
    parser.add_argument('--no-upload-scanning',action='store_true')
    args=parser.parse_args()
    ids=json.loads(Path(args.resources).read_text())
    expected={'workloadStorage':'Microsoft.Storage/storageAccounts','functionStorage':'Microsoft.Storage/storageAccounts','cosmos':'Microsoft.DocumentDB/databaseAccounts','functionApp':'Microsoft.Web/sites','foundry':'Microsoft.CognitiveServices/accounts','openAi':'Microsoft.CognitiveServices/accounts','databricks':'Microsoft.Databricks/workspaces'}
    scopes=set()
    for key,kind in expected.items():
        match=re.fullmatch(r'(/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/[^/]+)/providers/'+re.escape(kind)+r'/[^/]+',ids.get(key,''))
        if not match: raise ValueError(f'ID inválido: {key}')
        scopes.add((match[1],match[2]))
    if len(scopes)!=1: raise ValueError('Los recursos deben pertenecer al mismo RG y suscripción ESG.')
    rg,sid=scopes.pop()
    plans={p['name']:p['properties'] for p in get(f'/subscriptions/{sid}/providers/Microsoft.Security/pricings?api-version=2024-01-01')['value']}
    stores={key:get(ids[key]+'/providers/Microsoft.Security/defenderForStorageSettings/current?api-version=2025-06-01')['properties'] for key in ('workloadStorage','functionStorage')}
    errors=assess(plans,stores,not args.no_upload_scanning)
    ips={'cosmos':[],'functionApp':[]}
    for endpoint in get(rg+'/providers/Microsoft.Network/privateEndpoints?api-version=2024-05-01')['value']:
        props=endpoint['properties']
        for key in ips:
            matches=[c['properties'] for c in props.get('privateLinkServiceConnections',[])+props.get('manualPrivateLinkServiceConnections',[]) if c['properties'].get('privateLinkServiceId','').lower()==ids[key].lower()]
            if not matches: continue
            if not all(c.get('privateLinkServiceConnectionState',{}).get('status')=='Approved' for c in matches):
                errors.append(f'{key}: endpoint no aprobado.');continue
            for nic in props.get('networkInterfaces',[]):
                ips[key].extend(c['properties']['privateIPAddress'] for c in get(nic['id']+'?api-version=2024-05-01')['properties']['ipConfigurations'])
    for key in ips:
        ips[key]=sorted(set(ips[key]))
        if not ips[key]: errors.append(f'{key}: faltan IP de endpoints aprobados.')
    print(json.dumps({'cosmosPrivateIps':ips['cosmos'],'functionPrivateIps':ips['functionApp'],'storageConfiguration':stores,'issues':errors,'configurationChecked':not errors,'pending':'Verificar cobertura efectiva por recurso, exclusiones, escaneo real y recepción SOC. No acredita protección del DBFS administrado ni detección completa de Functions privadas.'},indent=2,ensure_ascii=False))
    return bool(errors)

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,KeyError,OSError,RuntimeError) as exc:
        print(f'Preflight incompleto: {exc}',file=sys.stderr);sys.exit(1)

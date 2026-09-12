#!/usr/bin/env python3
"""Verifica configuración de Defender e IP privadas mediante lecturas Azure; no cambia recursos."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

KINDS={'hostStorage':'Microsoft.Storage/storageAccounts','businessStorage':'Microsoft.Storage/storageAccounts','functionApp':'Microsoft.Web/sites','cosmos':'Microsoft.DocumentDB/databaseAccounts','openAi':'Microsoft.CognitiveServices/accounts','documentIntelligence':'Microsoft.CognitiveServices/accounts','vault':'Microsoft.KeyVault/vaults'}

def get(path):
    r=subprocess.run(['az','rest','--method','get','--url','https://management.azure.com'+path,'--output','json','--only-show-errors'],capture_output=True,text=True)
    if r.returncode: raise RuntimeError('Lectura incompleta.')
    return json.loads(r.stdout)

def assess(plans,storages,untrusted=True):
    errors=[]
    for name in ('CloudPosture','AppServices','KeyVaults','CosmosDbs','AI'):
        if plans.get(name,{}).get('pricingTier')!='Standard':errors.append(f'Confirmar plan corporativo {name} Standard.')
    for name in ('hostStorage','businessStorage'):
        if storages.get(name,{}).get('isEnabled') is not True:errors.append(f'Defender no confirmado: {name}.')
    if untrusted and storages.get('businessStorage',{}).get('malwareScanning',{}).get('onUpload',{}).get('isEnabled') is not True:
        errors.append('Análisis de malware al cargar documentos no confirmado.')
    return errors

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resources',required=True,help='Archivo con el valor del output securityResourceIds.')
    parser.add_argument('--no-untrusted-files',action='store_true',help='Solo con clasificación aprobada y processesUntrustedFiles=false.')
    args=parser.parse_args();ids=json.loads(Path(args.resources).read_text());scopes=set()
    for key,kind in KINDS.items():
        m=re.fullmatch(r'(/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/[^/]+)/providers/'+re.escape(kind)+r'/[^/]+',ids.get(key,''))
        if not m:raise ValueError('IDs inválidos.')
        scopes.add((m[1],m[2]))
    if len(scopes)!=1:raise ValueError('Los recursos deben pertenecer al mismo RG y suscripción nuevos.')
    rg,sid=scopes.pop()
    plans={v['name']:v['properties'] for v in get(f'/subscriptions/{sid}/providers/Microsoft.Security/pricings?api-version=2024-01-01')['value']}
    storages={key:get(ids[key]+'/providers/Microsoft.Security/defenderForStorageSettings/current?api-version=2025-06-01')['properties'] for key in ('hostStorage','businessStorage')}
    errors=assess(plans,storages,not args.no_untrusted_files)
    ips={'functionApp':[],'cosmos':[]}
    for pe in get(rg+'/providers/Microsoft.Network/privateEndpoints?api-version=2024-05-01')['value']:
        props=pe['properties']
        for key in ips:
            matching=[c['properties'] for c in props.get('privateLinkServiceConnections',[])+props.get('manualPrivateLinkServiceConnections',[]) if c['properties'].get('privateLinkServiceId','').lower()==ids[key].lower()]
            if not matching:continue
            if not all(c.get('privateLinkServiceConnectionState',{}).get('status')=='Approved' for c in matching):errors.append(f'Endpoint {key} no aprobado.');continue
            for nic in props.get('networkInterfaces',[]):
                ips[key].extend(c['properties']['privateIPAddress'] for c in get(nic['id']+'?api-version=2024-05-01')['properties']['ipConfigurations'])
    for key in ips:
        if not ips[key]:errors.append(f'No se encontraron IP privadas aprobadas: {key}.')
    print(json.dumps({'functionPrivateIps':sorted(set(ips['functionApp'])),'cosmosPrivateIps':sorted(set(ips['cosmos'])),'storageSettings':storages,'issues':errors,'configurationChecked':not errors,'pending':'Confirmar exclusiones, límites y herencia efectiva con Seguridad; planes activos no prueban cobertura de modelos/Batch o Document Intelligence, recepción SIEM, detección ni bloqueo de documentos.'},indent=2,ensure_ascii=False))
    return bool(errors)

if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,RuntimeError,TypeError):print('Verificación incompleta; revisar IDs, permisos y sesión. No se imprimen errores Azure ni secretos.',file=sys.stderr);sys.exit(1)

#!/usr/bin/env python3
"""Comprobación de solo lectura previa a actualizar los artefactos ADF del destino."""
import argparse,json,re,subprocess,sys

def check(triggers):
    return [f"Detener y verificar antes de actualizar: {t['name']}." for t in triggers if t['properties'].get('runtimeState')!='Stopped']

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--factory-resource-id',required=True);a=p.parse_args()
    if not re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.DataFactory/factories/[^/]+',a.factory_resource_id) or '/rg-poc-vinculador-cr/' in a.factory_resource_id.lower():raise ValueError()
    r=subprocess.run(['az','rest','--method','get','--url','https://management.azure.com'+a.factory_resource_id+'/triggers?api-version=2018-06-01','--only-show-errors','-o','json'],capture_output=True,text=True)
    if r.returncode:raise ValueError()
    errors=check(json.loads(r.stdout)['value']);print('\n'.join(errors) if errors else 'No hay triggers activos. Comprobar de nuevo tras actualizar; esto no detiene ni activa recursos.');return bool(errors)
if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,TypeError):print('No se pudo verificar el estado ADF; no continuar con la actualización.',file=sys.stderr);sys.exit(1)

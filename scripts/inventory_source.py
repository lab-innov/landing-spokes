#!/usr/bin/env python3
"""Inventario estructural de MOP Express en modo lectura. No consulta claves, app settings ni documentos."""
import argparse,json,subprocess,sys
from pathlib import Path
from datetime import datetime,timezone

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--subscription',required=True);p.add_argument('--output',required=True);a=p.parse_args()
    queries={
      'resources':(['resource','list','-g','RG-POC-PreMop-CR'],'[].{name:name,type:type,location:location}'),
      'containers':(['cosmosdb','sql','container','list','-g','RG-POC-PreMop-CR','-a','cdb-premop-cr','-d','premop-db'],'[].{name:name,partitionKey:resource.partitionKey,indexingPolicy:resource.indexingPolicy,defaultTtl:resource.defaultTtl,uniqueKeyPolicy:resource.uniqueKeyPolicy}'),
      'functionConfiguration':(['functionapp','config','show','-g','RG-POC-PreMop-CR','-n','azfunc-premop-CR'],'{linuxFxVersion:linuxFxVersion,alwaysOn:alwaysOn}'),
      'documentsStorage':(['storage','account','show','-g','RG-POC-PreMop-CR','-n','aspremop'],'{name:name,sku:sku.name,kind:kind}'),
      'plan':(['appservice','plan','show','-g','RG-POC-PreMop-CR','-n','APPSP-PoCPreMop-cr'],'{name:name,sku:sku.name,capacity:sku.capacity}')
    }
    out={'checkedAt':datetime.now(timezone.utc).isoformat(),'sourceResourceGroup':'RG-POC-PreMop-CR','readOnly':True,'databaseName':'premop-db'}
    for k,(args,query) in queries.items():
        r=subprocess.run(['az',*args,'--subscription',a.subscription,'--query',query,'--only-show-errors','-o','json'],capture_output=True,text=True)
        if r.returncode:raise RuntimeError()
        out[k]=json.loads(r.stdout)
    Path(a.output).write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n');print('Inventario estructural guardado; pendientes código y pruebas operativas.')
if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError):print('Inventario incompleto; revisar sesión y permisos. No se muestran respuestas Azure ni secretos.',file=sys.stderr);sys.exit(1)

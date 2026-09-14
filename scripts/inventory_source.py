#!/usr/bin/env python3
"""Recupera inventario estructural de ADF y Cosmos en modo lectura. Nunca lista claves, secretos o app settings."""
import argparse,json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path

def run(args):
    r=subprocess.run(['az',*args,'--only-show-errors','-o','json'],capture_output=True,text=True)
    if r.returncode:raise RuntimeError()
    return json.loads(r.stdout)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for n in ('subscription','resource-group','factory','cosmos','output'):p.add_argument('--'+n,required=True)
    a=p.parse_args();base=f'https://management.azure.com/subscriptions/{a.subscription}/resourceGroups/{a.resource_group}/providers/Microsoft.DataFactory/factories/{a.factory}'
    result={'checkedAt':datetime.now(timezone.utc).isoformat(),'sourceResourceGroup':a.resource_group,'readOnly':True}
    queries={
      'pipelines':'value[].{name:name,parameters:properties.parameters,activities:properties.activities[].{name:name,type:type,linkedService:linkedServiceName.referenceName,notebookPath:typeProperties.notebookPath,fileName:typeProperties.baseParameters.fileName,policy:policy}}',
      'triggers':'value[].{name:name,type:properties.type,runtimeState:properties.runtimeState,blobPathBeginsWith:properties.typeProperties.blobPathBeginsWith,blobPathEndsWith:properties.typeProperties.blobPathEndsWith,ignoreEmptyBlobs:properties.typeProperties.ignoreEmptyBlobs,events:properties.typeProperties.events,pipelines:properties.pipelines}',
      'linkedservices':'value[].{name:name,type:properties.type,domain:properties.typeProperties.domain,clusterId:properties.typeProperties.existingClusterId,authentication:properties.typeProperties.authentication}'
    }
    for resource,q in queries.items():result[resource]=run(['rest','--method','get','--url',base+'/'+resource+'?api-version=2018-06-01','--query',q])
    common=['--subscription',a.subscription,'-g',a.resource_group,'-a',a.cosmos]
    databases=run(['cosmosdb','sql','database','list',*common,'--query','[].name'])
    result['databases']=[{'name':db,'containers':run(['cosmosdb','sql','container','list',*common,'-d',db,'--query','[].{name:name,partitionKey:resource.partitionKey,indexingPolicy:resource.indexingPolicy,defaultTtl:resource.defaultTtl,uniqueKeyPolicy:resource.uniqueKeyPolicy,conflictResolutionPolicy:resource.conflictResolutionPolicy}'])} for db in databases]
    Path(a.output).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n');print('Inventario estructural guardado; no acredita código, datos ni conectividad.')
if __name__=='__main__':
    try:main()
    except (OSError,RuntimeError,ValueError):print('Inventario incompleto; revisar acceso Azure. No se imprimen respuestas de error.',file=sys.stderr);sys.exit(1)

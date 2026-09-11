#!/usr/bin/env python3
"""Valida constancia operativa del responsable antes de iniciar triggers; no genera evidencia."""
import datetime as dt
import json
import sys
from pathlib import Path

def check(evidence,rg,factory,now=None):
    errors=[]
    if evidence.get('resourceGroup')!=rg or evidence.get('dataFactory')!=factory: errors.append('La evidencia no corresponde al RG y factory solicitados.')
    for key in ('approvalId','approvedBy'):
        if not evidence.get(key) or 'REPLACE' in evidence[key].upper(): errors.append(f'Falta {key} real.')
    for key in ('networkVerified','defenderVerified','siemVerified','applicationVerified','dataMigrationVerified','pipelineTestsVerified'):
        if evidence.get(key) is not True: errors.append(f'Falta evidencia de {key}.')
    if evidence.get('scanUploads',True) and evidence.get('uploadGateVerified') is not True: errors.append('Falta control de procesamiento de archivos analizados.')
    try:
        approved=dt.datetime.fromisoformat(evidence['approvedAt'].replace('Z','+00:00'))
        age=(now or dt.datetime.now(dt.timezone.utc))-approved
        if not dt.timedelta(0)<=age<=dt.timedelta(days=7): errors.append('La evidencia debe tener como máximo siete días y no estar en el futuro.')
    except (ValueError,KeyError,TypeError): errors.append('Fecha approvedAt inválida; usar ISO8601 con zona horaria.')
    return errors

if __name__=='__main__':
    try: errors=check(json.loads(Path(sys.argv[1]).read_text()),sys.argv[2],sys.argv[3])
    except (ValueError,OSError,IndexError): errors=['Indicar archivo JSON de evidencia, RG y factory.']
    print('\n'.join(errors) if errors else 'Constancia operativa válida; conservar evidencia de las pruebas.')
    sys.exit(bool(errors))

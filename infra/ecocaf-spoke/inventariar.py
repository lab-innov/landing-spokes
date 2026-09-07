#!/usr/bin/env python3
"""Recoge metadatos de ECOCAF mediante consultas de solo lectura, sin valores secretos."""

import argparse
import json
import subprocess


def collect(subscription, resource_group, app, runner=subprocess.run):
    pending = []

    def query(label, command, projection):
        try:
            result = runner(
                ['az', *command, '--subscription', subscription, '--query', projection,
                 '--output', 'json', '--only-show-errors'],
                capture_output=True, text=True, timeout=90, check=False,
            )
            if result.returncode:
                # No volcar stderr: podría contener datos de configuración del proveedor.
                pending.append({'consulta': label, 'estado': 'fallida', 'codigo': result.returncode})
                return None
            return json.loads(result.stdout)
        except (subprocess.TimeoutExpired, OSError, json.JSONDecodeError) as exc:
            pending.append({'consulta': label, 'estado': type(exc).__name__})
            return None

    scope = ['--resource-group', resource_group, '--name', app]
    report = {
        'suscripcion': subscription,
        'grupo': resource_group,
        'app': app,
        'alcance': 'Metadatos del grupo y Function App; no incluye datos ni dependencias externas completas.',
        'recursos': query('recursos', ['resource', 'list', '-g', resource_group],
                          '[].{id:id,name:name,type:type,location:location}'),
        'aplicacion': query('aplicacion', ['functionapp', 'show', *scope],
                           '{id:id,kind:kind,state:state,plan:serverFarmId,identity:identity,subnet:virtualNetworkSubnetId,publicNetworkAccess:publicNetworkAccess,hostNames:hostNames}'),
        'nombres_ajustes': query('ajustes', ['functionapp', 'config', 'appsettings', 'list', *scope],
                               '[].{name:name,slotSetting:slotSetting}'),
        'nombres_conexiones': query('conexiones', ['webapp', 'config', 'connection-string', 'list', *scope],
                                   '[].{name:name,type:type,slotSetting:slotSetting}'),
        'runtime': query('runtime', ['functionapp', 'config', 'show', *scope],
                         '{linuxFxVersion:linuxFxVersion,alwaysOn:alwaysOn,vnetRouteAllEnabled:vnetRouteAllEnabled}'),
        'autenticacion': query('autenticacion', ['webapp', 'auth', 'show', *scope],
                               '{platform:platform,globalValidation:globalValidation}'),
        'funciones': query('funciones', ['functionapp', 'function', 'list', *scope], '[].{name:name}'),
        'slots': query('slots', ['functionapp', 'deployment', 'slot', 'list', *scope], '[].{name:name,id:id}'),
        'integracion_vnet': query('integracion_vnet', ['webapp', 'vnet-integration', 'list', *scope],
                                  '[].{id:id,subnetResourceId:subnetResourceId}'),
    }
    report['pendientes'] = pending
    report['estado'] = 'parcial_con_errores' if pending else 'metadatos_recogidos_dependencias_pendientes'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--subscription', required=True)
    parser.add_argument('--resource-group', required=True)
    parser.add_argument('--app', default='azfun-POC-ECO-CAF-CR')
    args = parser.parse_args()
    report = collect(args.subscription, args.resource_group, args.app)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if report['pendientes'] else 0


if __name__ == '__main__':
    raise SystemExit(main())

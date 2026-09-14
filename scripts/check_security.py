#!/usr/bin/env python3
"""Preflight de solo lectura: configuración Defender e IP de endpoints; no acredita recepción en SIEM."""
import argparse
import ipaddress
import json
import subprocess
import sys


def get(path):
    result = subprocess.run(['az', 'rest', '--method', 'get', '--url', 'https://management.azure.com' + path, '--output', 'json', '--only-show-errors'], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError('Azure no permitió leer ' + path.split('?')[0])
    return json.loads(result.stdout)


def assess(plans, stores, registry, require_scan=True):
    errors = []
    for name in ('KeyVaults', 'CosmosDbs', 'AI', 'CloudPosture'):
        if plans.get(name, {}).get('pricingTier') != 'Standard':
            errors.append(f'Plan {name}: cobertura Standard no acreditada; coordinar con plataforma.')
    registry_scan = any(p.get('pricingTier') == 'Standard' and any(e.get('name') == 'ContainerRegistriesVulnerabilityAssessments' and str(e.get('isEnabled')).lower() == 'true' for e in p.get('extensions', [])) for p in (plans.get('Containers', {}), plans.get('CloudPosture', {})))
    if not registry_scan:
        errors.append('Análisis de imágenes ACR no acreditado en Containers/CloudPosture.')
    if registry.get('networkRuleBypassOptions') != 'AzureServices':
        errors.append('ACR no permite el acceso de servicios de confianza requerido por Defender.')
    for name, settings in stores.items():
        if settings.get('isEnabled') is not True:
            errors.append(f'{name}: Defender for Storage no habilitado.')
        if name == 'storage' and require_scan:
            scan = settings.get('malwareScanning', {}).get('onUpload', {})
            if scan.get('isEnabled') is not True:
                errors.append('uploads: análisis de malware no habilitado en configuración efectiva.')
            cap = scan.get('capGBPerMonth')
            if type(cap) is not int or (cap != -1 and cap <= 0):
                errors.append('uploads: límite de análisis no acreditado.')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resources', required=True, help='JSON con el valor del output securityResourceIds.')
    parser.add_argument('--no-upload-scanning', action='store_true', help='Solo para soluciones cuyo riesgo aprobado no exige análisis de cargas.')
    args = parser.parse_args()
    with open(args.resources) as stream:
        ids = json.load(stream)
    expected = {'storage':'Microsoft.Storage/storageAccounts', 'agentStorage':'Microsoft.Storage/storageAccounts', 'registry':'Microsoft.ContainerRegistry/registries', 'vault':'Microsoft.KeyVault/vaults', 'cosmos':'Microsoft.DocumentDB/databaseAccounts', 'foundry':'Microsoft.CognitiveServices/accounts'}
    subscriptions = set()
    import re
    for key, kind in expected.items():
        match = re.fullmatch(r'/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/[^/]+/providers/' + re.escape(kind) + r'/[^/]+', ids.get(key, ''))
        if not match:
            raise ValueError(f'ID inválido: {key}')
        subscriptions.add(match[1])
    if len(subscriptions) != 1:
        raise ValueError('Los recursos del spoke deben pertenecer a la misma suscripción.')
    sid = subscriptions.pop()
    plans = {x['name']: x['properties'] for x in get(f'/subscriptions/{sid}/providers/Microsoft.Security/pricings?api-version=2024-01-01')['value']}
    stores = {key:get(ids[key] + '/providers/Microsoft.Security/defenderForStorageSettings/current?api-version=2025-06-01')['properties'] for key in ('storage','agentStorage')}
    registry = get(ids['registry'] + '?api-version=2023-07-01')['properties']
    errors = assess(plans, stores, registry, not args.no_upload_scanning)
    addresses = {'vault':[], 'cosmos':[]}
    # Enumerar endpoints del RG del spoke y resolver las NIC; no inferir nombres ni IP.
    rg_path = ids['vault'].split('/providers/')[0]
    endpoints = get(rg_path + '/providers/Microsoft.Network/privateEndpoints?api-version=2024-05-01')['value']
    for endpoint in endpoints:
        props = endpoint['properties']
        connections = props.get('privateLinkServiceConnections', []) + props.get('manualPrivateLinkServiceConnections', [])
        for key in addresses:
            relevant = [c['properties'] for c in connections if c['properties'].get('privateLinkServiceId', '').lower() == ids[key].lower()]
            if not relevant:
                continue
            if not all(c.get('privateLinkServiceConnectionState', {}).get('status') == 'Approved' for c in relevant):
                errors.append(f'{key}: endpoint no aprobado.')
                continue
            for nic in props.get('networkInterfaces', []):
                for config in get(nic['id'] + '?api-version=2024-05-01')['properties']['ipConfigurations']:
                    addresses[key].append(str(ipaddress.IPv4Address(config['properties']['privateIPAddress'])))
    for key in addresses:
        addresses[key] = sorted(set(addresses[key]))
        if not addresses[key]:
            errors.append(f'{key}: no se encontraron IP de endpoints aprobados.')
    print(json.dumps({'privateServiceAddresses':addresses, 'storageConfiguration':stores, 'issues':errors, 'result':'CONFIGURACION_PENDIENTE' if errors else 'CONFIGURACION_VERIFICADA', 'pending':'Comprobar análisis real de imagen/archivo, conectividad y recepción en SIEM; este script no acredita protección en ejecución de ACA.'}, indent=2, ensure_ascii=False))
    return 1 if errors else 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, RuntimeError, OSError) as exc:
        print(f'Preflight incompleto: {exc}', file=sys.stderr)
        sys.exit(1)

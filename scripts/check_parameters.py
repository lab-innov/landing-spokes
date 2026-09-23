#!/usr/bin/env python3
"""Comprueba el contrato local; no sustituye IPAM, DNS ni validación Azure."""
import ipaddress
import json
import re
import sys
from pathlib import Path

PRIVATE = tuple(ipaddress.ip_network(n) for n in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'))
RESERVED = tuple(ipaddress.ip_network(n) for n in ('172.30.0.0/16', '172.31.0.0/16'))

def subnets(prefix):
    net = ipaddress.IPv4Network(prefix, strict=True)
    if net.prefixlen != 24:
        raise ValueError('vnetPrefix debe ser /24.')
    base = int(net.network_address)
    return {name: ipaddress.IPv4Network((base + offset, size)) for name, offset, size in (
        ('foundry', 0, 25), ('containers', 128, 26), ('privateEndpoints', 192, 27), ('appGateway', 224, 27))}

def check(p):
    errors = []
    def require(ok, message):
        if not ok:
            errors.append(message)
    def resource_id(value, kind):
        return isinstance(value, str) and re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/' + re.escape(kind) + r'/[^/]+', value)
    require('REEMPLAZAR' not in json.dumps(p), 'Sustituir todos los marcadores REEMPLAZAR.')
    require(p.get('location', 'eastus') == 'eastus', 'Esta variante usa East US.')
    require(bool(re.fullmatch(r'[a-z0-9-]{2,12}', p.get('workload', ''))), 'workload: 2-12 caracteres a-z, 0-9 o guion.')
    require(bool(p.get('tags', {}).get('iniciativa')), 'Etiqueta iniciativa requerida.')
    require(bool(p.get('tags', {}).get('DataClassification')), 'Etiqueta DataClassification requerida.')
    require(p.get('tags', {}).get('OpsDept') == 'DTI', 'Etiqueta OpsDept debe ser DTI.')
    require(bool(p.get('tags', {}).get('UserDept')), 'Etiqueta UserDept requerida.')
    require(type(p.get('modelsApproved',False)) is bool, 'modelsApproved debe ser booleano.')
    require(not p.get('models') or p.get('modelsApproved') is True, 'Confirmar aprobación explícita de modelos.')
    require(not any(p.get(k) for k in ('activateAgentRuntime','deployApplications','deployGateway')) or bool(p.get('securityApprovalId')), 'Activación requiere identificador de aprobación.')
    nets = {}
    try:
        net = ipaddress.IPv4Network(p.get('vnetPrefix', ''), strict=True)
        nets = subnets(str(net))
        require(any(net.subnet_of(n) for n in PRIVATE), 'VNet: usar RFC1918.')
        require(not any(net.overlaps(n) for n in RESERVED), 'VNet se solapa con rangos reservados por ACA.')
    except ValueError as exc:
        errors.append(str(exc))
    for key in ('cafClientPrefixes',):
        values = p.get(key, [])
        require(isinstance(values, list) and bool(values), f'{key}: lista no vacía requerida.')
        for value in values if isinstance(values, list) else []:
            try:
                candidate = ipaddress.ip_network(value, strict=True)
                require(candidate.version == 4 and any(candidate.subnet_of(n) for n in PRIVATE), f'{key}: usar IPv4 privada.')
                if nets:
                    require(not candidate.overlaps(net), 'Clientes VPN y VNet no deben solaparse.')
            except (ValueError, TypeError):
                errors.append(f'{key}: dirección inválida.')
    for key, kind in [('logAnalyticsWorkspaceId', 'Microsoft.OperationalInsights/workspaces'), ('actionGroupId', 'Microsoft.Insights/actionGroups')]:
        require(bool(resource_id(p.get(key), kind)), f'{key}: ID completo requerido.')
    require(set(p.get('privateDnsZoneResourceIds',{}))=={'account','blob','vault','registry','Sql','searchService'},'Definir todas las zonas DNS privadas de Foundry.')
    for purpose in ('foundry', 'containers', 'appGateway'):
        require(bool(resource_id(p.get('routeTableIds', {}).get(purpose), 'Microsoft.Network/routeTables')), f'routeTableIds.{purpose}: ID completo requerido.')
    for flag in ('networkReady', 'monitoringReady', 'applicationAuthVerified', 'gatewayReady', 'activateAgentRuntime', 'deployApplications', 'deployGateway'):
        require(type(p.get(flag, False)) is bool, f'{flag}: debe ser booleano.')
    for flag in ('defenderCoverageVerified', 'siemDeliveryVerified', 'uploadGateVerified', 'scanUploads'):
        require(type(p.get(flag, flag == 'scanUploads')) is bool, f'{flag}: debe ser booleano.')
    if p.get('activateAgentRuntime'):
        for key in ('defenderCoverageVerified', 'siemDeliveryVerified'):
            require(p.get(key) is True, f'Runtime requiere {key}.')
    addresses = p.get('privateServiceAddresses', {})
    for key in ('vault', 'cosmos'):
        values = addresses.get(key, [])
        require(isinstance(values, list), f'privateServiceAddresses.{key}: lista requerida.')
        for value in values if isinstance(values, list) else []:
            try:
                address = ipaddress.IPv4Address(value)
                require(bool(nets) and address in nets['privateEndpoints'] and int(address) - int(nets['privateEndpoints'].network_address) >= 4 and address != nets['privateEndpoints'].broadcast_address, f'{key}: IP fuera de endpoints o reservada.')
            except (ValueError, TypeError):
                errors.append(f'{key}: IP inválida.')
    require(not p.get('activateAgentRuntime') or bool(addresses.get('cosmos')), 'Runtime requiere IP reales de Cosmos.')
    require(not p.get('deployGateway') or bool(addresses.get('vault')), 'Gateway requiere IP real de Key Vault.')
    for key in ('operatorPrefixes', 'monitorPrefixes'):
        for value in p.get(key, []):
            try:
                candidate = ipaddress.ip_network(value, strict=True)
                require(candidate.version == 4 and any(candidate.subnet_of(n) for n in PRIVATE), f'{key}: usar red privada.')
            except (ValueError, TypeError):
                errors.append(f'{key}: red inválida.')
    if p.get('deployApplications'):
        require(bool(p.get('monitorPrefixes')), 'Aplicaciones requieren IP de AMPLS.')
        require(not p.get('scanUploads', True) or p.get('uploadGateVerified') is True, 'Aplicación debe verificar resultado limpio de malware.')
    secrets = p.get('backendSecretNames', [])
    require(len(secrets) == len(set(v.lower() for v in secrets)), 'No repetir secretos.')
    require(p.get('certificateSecretName', 'appgateway-tls').lower() not in [v.lower() for v in secrets], 'Backend no puede leer certificado del gateway.')
    for secret in secrets:
        require(bool(re.fullmatch(r'[a-zA-Z0-9-]{1,127}', secret)), 'Nombre de secreto inválido.')
    for purpose, rules in p.get('extraEgress', {}).items():
        require(purpose in ('foundry', 'containers', 'appGateway') or (purpose == 'privateEndpoints' and not rules), 'No se permiten excepciones en endpoints ni subredes desconocidas.')
        require(len(rules) <= 100, 'Máximo 100 excepciones por subred.')
        for rule in rules:
            require(bool(rule.get('justification', '').strip()) and len(rule.get('justification', '')) <= 140, 'Excepción requiere justificación de hasta 140 caracteres.')
            try:
                destination = ipaddress.IPv4Network(rule.get('destination', ''), strict=True)
                require(destination.prefixlen >= 24, 'Excepción requiere destino /24 o más específico; FQDN se controla en firewall CAF.')
            except (ValueError, TypeError):
                errors.append('Destino de excepción debe ser IPv4/CIDR explícito.')
            ports = rule.get('ports', [])
            require(bool(ports), 'Excepción requiere puertos.')
            for port in ports:
                require(isinstance(port, str) and port.isdigit() and 1 <= int(port) <= 65535, 'Puertos de excepción: números individuales 1-65535.')
    event_id = p.get('siemAuthorizationRuleId', '')
    event_name = p.get('siemEventHubName', '')
    require(bool(event_id) == bool(event_name), 'Event Hub requiere ID de regla y nombre juntos.')
    if event_id:
        require(bool(re.fullmatch(r'/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.EventHub/namespaces/[^/]+/authorizationRules/[^/]+', event_id)), 'Event Hub requiere ID de regla de autorización del namespace.')
    reserved_env = {'BACKEND_URL', 'AZURE_CLIENT_ID', 'AZURE_AI_PROJECT_ENDPOINT', 'AZURE_STORAGE_BLOB_ENDPOINT', 'AZURE_STORAGE_CONTAINER', 'AZURE_KEY_VAULT_URL'}
    for key in ('frontendEnv', 'backendEnv'):
        for entry in p.get(key, []):
            require(entry.get('name') not in reserved_env, f'{key}: no sobrescribir conexiones del contrato.')
    models = p.get('models', [])
    require(isinstance(models, list), 'models: lista requerida.')
    for model in models if isinstance(models, list) else []:
        require(isinstance(model, dict) and all(model.get(k) for k in ('name', 'model', 'version', 'sku')) and type(model.get('capacity')) is int and model['capacity'] > 0, 'Modelo: nombre, versión, SKU y capacidad positiva requeridos.')
    require(not p.get('activateAgentRuntime') or p.get('networkReady'), 'Runtime requiere networkReady.')
    if p.get('deployApplications'):
        for key in ('activateAgentRuntime', 'applicationAuthVerified', 'monitoringReady'):
            require(p.get(key) is True, f'Aplicaciones requieren {key}.')
        require(bool(models), 'Aplicaciones requieren modelos explícitos.')
        for key in ('frontendImage', 'backendImage'):
            require(bool(re.fullmatch(r'[a-z0-9]+\.azurecr\.io/[^\s]+@sha256:[a-f0-9]{64}', p.get(key, ''))), f'{key}: imagen ACR fijada por digest requerida.')
    if p.get('deployGateway'):
        require(p.get('deployApplications') and p.get('gatewayReady'), 'Gateway requiere aplicaciones y gatewayReady.')
        require(bool(re.fullmatch(r'[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', p.get('gatewayHostname', ''))), 'Hostname TLS requerido.')
        try:
            ip = ipaddress.IPv4Address(p.get('gatewayPrivateIp', ''))
            subnet = nets['appGateway']
            require(ip in subnet and int(ip) - int(subnet.network_address) >= 4 and ip != subnet.broadcast_address, 'IP del gateway fuera de subred o reservada.')
        except (ValueError, KeyError):
            errors.append('IP privada del gateway inválida.')
    return errors

if __name__ == '__main__':
    try:
        document = json.loads(Path(sys.argv[1]).read_text())
        errors = check({k: v['value'] for k, v in document['parameters'].items()})
    except (ValueError, KeyError, TypeError, IndexError) as exc:
        errors = [f'Archivo de parámetros inválido: {exc}']
    if errors:
        print('\n'.join(f'- {error}' for error in errors))
        sys.exit(1)
    print('Contrato local válido. Pendientes IPAM, DNS, RBAC, imágenes y validación Azure.')

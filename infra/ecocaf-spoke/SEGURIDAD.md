# Seguridad y despliegue ECOCAF

## Parámetros nuevos

`routeTableResourceId` sustituye `firewallPrivateIp`: se asocia una tabla existente
sin escribir sus rutas. Confirmar región, suscripción y permisos de asociación.
La VNet usa DNS de Azure; no configura servidores DNS personalizados ni peering.
Plataforma debe crear manualmente la conexión de Virtual WAN de producción.
No se crean firewall, VPN Gateway, Bastion, resolvers ni direcciones IP públicas.

| Parámetro | Responsable / contenido |
| --- | --- |
| `tags.iniciativa`, `tags.DataClassification`, `tags.OpsDept`, `tags.UserDept` | Identidad, clasificación y departamentos; `OpsDept` debe ser `DTI` |
| `privateDnsZoneResourceIds` | IDs completos de Blob, Queue, Table y Azure Websites en `RG-PRIVATEDNS-PR` |
| `apiClientPrefixes` | Redes VPN/APIM autorizadas para la API |
| `operatorPrefixes` | Ejecutores/operadores privados autorizados, no toda la VPN |
| `monitorPrefixes` | IP/CIDR de endpoints AMPLS corporativos |
| `functionPrivateIps` | IP reales del endpoint sites, descubiertas tras la fundación |
| `allowedPrincipalIds` | Object IDs de usuarios o identidades de servicio autorizados (máximo 13), no grupos ni client IDs |
| `extraEgress` | Lista de salidas TCP excepcionales por IP/CIDR, puertos individuales y justificación |
| `actionGroupResourceId` | Action Group corporativo existente |
| `siemAuthorizationRuleId`, `siemEventHubName` | Destino Event Hub corporativo; proporcionar ambos o ninguno |
| `processesUntrustedFiles` | Declaración según inventario y análisis de riesgo de los archivos procesados |
| `hostUsesTables`, `hostUsesBlobTriggers`, `hostUsesDurableStorage` | Capacidades realmente usadas por bindings del código |

## Red y permisos

Un NSG limita conexiones por origen/destino/puerto. No autentica al usuario ni
filtra malware. Los dos NSG terminan en denegación explícita antes de los permisos
predeterminados de Azure:

- Integración Functions a endpoints del spoke por TCP 443.
- Clientes VPN/APIM a las IP del endpoint Function por TCP 443, sin abrirles los
  endpoints de Storage. El endpoint sites incluye app y SCM: la red no distingue
  ambos nombres; mantener SCM sin autenticación básica y publicar mediante Entra.
- Operadores declarados a endpoints por TCP 443; los roles del servicio siguen
  siendo necesarios. Se mantiene TLS mínimo 1.2.
- Salida de Functions a DNS de Azure, puerto 53; Entra/Monitor por
  TCP 443; AMPLS por las IP corporativas declaradas.
- Excepciones `extraEgress`: `purpose: functionsIntegration`, `destination`,
  `ports`, `justification`. IPv4/CIDR /24 o más específico, puertos TCP individuales,
  máximo 100 reglas y justificación de hasta 140 caracteres. No usar Internet
  genérico. Las reglas FQDN y rutas de retorno se coordinan en el firewall CAF.

Sin `functionPrivateIps` no existe permiso de entrada para clientes. El script
`check_security.py` descubre IP después de crear los endpoints; verificar que
pertenecen a la subred de endpoints. Su recreación exige actualizar las reglas.
No se inventan IP estáticas para el servicio.

La tabla de rutas se asocia a ambas subredes; revisar cómo afectan sus rutas a los
endpoints y a las respuestas. Cada endpoint queda asociado mediante un grupo DNS
a la zona central suministrada para `privatelink.azurewebsites.net` (app y SCM),
Blob, Queue y Table. Confirmar resolución privada desde Azure/VPN y el agente de
publicación; el enlace DNS no prueba conectividad de Virtual WAN.

Entra exige token de la audiencia de la API y object ID autorizado. Probar 401 sin
token y 403 para identidad no autorizada. Autorización de negocio por documento,
usuario o rol sigue siendo responsabilidad de la aplicación.

Blob Data Owner se limita al Storage exclusivo del host. Table Data Contributor
solo se asigna con `hostUsesTables` o Durable; Queue Contributor con Blob triggers
o Durable; Storage Account Contributor solo con Blob triggers. No se conceden
roles sobre datos de negocio desconocidos. Revisar requerimientos reales del host
antes de activar esas opciones.

## Defender y archivos

Se crea `defenderForStorageSettings/current` en el Storage de host, habilitado
con herencia de suscripción. No se modifican planes de suscripción, límites ni
exclusiones CAF. Si existe una configuración local anterior, revisar si restaurar
herencia reduce protección antes de desplegar.

```bash
python3 infra/ecocaf-spoke/check_security.py --resources /ruta/privada/recursos-ecocaf.json
```

El JSON contiene el valor del output `securityResourceIds`. El script consulta
solo la suscripción/RG derivados de los IDs, sin secretos, y comprueba planes
AppServices y CloudPosture, Defender del host y el endpoint Function aprobado.
Un fallo de lectura no produce un resultado satisfactorio. El informe solo
acredita configuración de estos recursos, no recepción de alertas ni cobertura
efectiva de todos los componentes de la aplicación.

Verificar las limitaciones de protección de Functions Linux privadas y de análisis
serverless sin acceso a Internet. No abrir públicamente la API para permitir un
scanner. No se habilitan planes AI, Cosmos, Key Vault o Containers hasta confirmar
recursos que los requieran; el inventario actual no contiene esos recursos.

Si `processesUntrustedFiles=true`, se exige `fileScanningVerified=true` antes de
activar: identificar dónde llegan los documentos y comprobar análisis real y
bloqueo de procesamiento hasta resultado limpio. Si están en otro Storage,
proteger ese Storage explícitamente. Si llegan directamente a HTTP, Defender del
host no intercepta ese flujo. No habilitar por inferencia un scanner sobre blobs
internos del runtime.

Las etiquetas del blob son modificables; no deben ser la única evidencia del
resultado. El pipeline debe tratar errores, archivos pendientes/no analizados y
agotamiento del límite de escaneo. Si CAF habilita malware scanning, preservar
identidad, permisos y recursos administrados por el scanner; verificar que
redeploys/políticas no eliminen sus ACL. No se crea un tema público de resultados.

## Auditoría, SIEM y alertas

Métricas de cuenta, logs de Blob/Queue/Table y logs de Function se envían al Log
Analytics corporativo. Event Hub es opcional si ya existe un pipeline desde LAW.
La regla suministrada es del namespace y debe ser compatible con diagnósticos
(Manage/Send/Listen); no se entrega una clave al Bicep. Revisar región, permisos y
acceso de servicios de confianza del namespace.

SOC administra conector hacia Taegis, retención y exportación separada de Activity
Logs y alertas Defender. `siemVerified` requiere evidencia de recepción de eventos
correlacionables de ECOCAF, no solo que exista un diagnostic setting.
No se crea ni configura Application Insights. La observabilidad de aplicación debe
integrarse con Dynatrace según el proceso de plataforma; los diagnósticos de recursos
se conservan hacia Log Analytics y el destino SIEM acordado.

Alertas al Action Group: más de 5 respuestas HTTP 5xx y más de
`requestsAlertThreshold` solicitudes (10.000 inicialmente), en ventanas de cinco
minutos. Ajustar con mediciones; no son sonda sintética de disponibilidad ni
contabilidad de tokens del APIM.
No introducir secretos o contenido documental en trazas sin política aprobada.

## Etapas y validación

1. Cerrar [inventario](INVENTARIO.md), clasificación, dependencias, nombres/RG
   nuevos, IPAM y contrato con plataforma. El código no está en este repositorio.
2. Compilar y comprobar parámetros. Para un bicepparam real, compilar a un archivo
   temporal privado antes de ejecutar el comprobador; eliminarlo después porque
   puede contener ajustes de aplicación. Nunca guardar esos valores en Git.
3. Ejecutar validate/what-if con suscripción y RG de destino explícitos. Desplegar
   fundación solo dentro de una ventana autorizada, con `activateFunctionApp=false`.
4. Completar DINE, endpoints, rutas y RBAC; descubrir IP de Function. Recuperar el
   paquete Python y publicar con Entra desde un ejecutor CAF. Confirmar mecanismos
   de publicación/contenido compatibles con P1v3; no copiar claves ni leases del host.
5. Revisar evidencias: `inventoryVerified`, `networkVerified`, `defenderVerified`,
   `siemVerified`, `applicationVerified`, `securityApprovalId` y control de archivos
   cuando aplique. Con allowlist, IP y Action Group completos, activar de forma
   controlada. Pruebas previas del paquete pueden realizarse en ensayo.
6. En destino probar host, datos, dependencias, 23 rutas HTTP, rechazo público,
   401/403, trazas y alertas antes de cambiar consumidores. La activación no ejecuta
   esas pruebas ni declara producción automáticamente.

```bash
./infra/ecocaf-spoke/validate.sh
python3 infra/ecocaf-spoke/check_parameters.py /ruta/privada/parametros.json
az deployment group validate --subscription SUSCRIPCION_DESTINO --resource-group RG_NUEVO --template-file infra/ecocaf-spoke/main.bicep --parameters @/ruta/privada/parametros.json
az deployment group what-if --subscription SUSCRIPCION_DESTINO --resource-group RG_NUEVO --template-file infra/ecocaf-spoke/main.bicep --parameters @/ruta/privada/parametros.json
```

Los indicadores son declaraciones respaldadas por evidencias, no sondas ni firmas.
Los contratos ARM rechazan combinaciones de activación inválidas; el comprobador
local añade validación de CIDR, IDs y excepciones. `applicationSettings` reemplaza
la colección completa de configuración específica; no usar diccionarios parciales.
No redefinir AzureWebJobsStorage ni runtime. Revisar aparte variables de paquetes,
montajes y referencias a Key Vault; sus dependencias no se crean automáticamente.

## Actualizaciones, capacidad y reversión

No aplicar parámetros de fundación sobre una aplicación operativa: false la
**detiene**. Conservar flags y configuración completos en siguientes despliegues.
Mantener origen y datos para reversión, sin escribir en sus recursos desde el destino
hasta controlar los efectos. Definir reconciliación si hubo escrituras durante pruebas.

ARM incremental no elimina la tabla local anterior ni roles omitidos. Revisar
what-if, cambiar asociación a tabla CAF y retirar recursos/asignaciones antiguas
solo mediante procedimiento explícito del responsable. No afirmar permisos mínimos
efectivos mientras permanezcan roles amplios heredados o directos.

P1v3 de una instancia y LRS no ofrecen redundancia zonal de esta carga. Se mantienen
para conservar el dimensionamiento conocido. Recuperación Blob/containers: 14 días;
versiones cuando HNS está deshabilitado. Definir RTO/RPO y probar restauración,
capacidad y dependencias antes de declarar resiliencia.

## Fuentes verificadas

- [Identidad y roles del host Functions](https://learn.microsoft.com/azure/azure-functions/functions-identity-based-connections-tutorial).
- [Configuración de Functions](https://learn.microsoft.com/azure/azure-functions/functions-app-settings).
- [Autorización Entra](https://learn.microsoft.com/azure/app-service/configure-authentication-provider-microsoft).
- [Defender serverless y limitaciones](https://learn.microsoft.com/azure/defender-for-cloud/serverless-protection).
- [Malware scanning y resultados](https://learn.microsoft.com/azure/defender-for-cloud/introduction-malware-scanning).

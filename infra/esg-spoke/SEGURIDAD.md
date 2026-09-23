# Preparación, seguridad y activación ESG

## Fundación

Copiar `environments/esg-spoke/esg-spoke.example.bicepparam` a un archivo privado.
Completar suscripción/RG de destino, cinco CIDR IPAM sin solapamiento, IDs de
zonas DNS centrales, rutas, Log Analytics, tenant, registro Entra y etiquetas
`iniciativa`, `OpsDept=DTI`, `UserDept` y `DataClassification`. No reutilizar
`RG-POC-ESG-CR`.

Para fundación usar `activateWorkload=false`, listas de modelos vacías y
`deployGroundingWithBing=false`, salvo selección de modelos y excepción ya
confirmadas. Los modelos históricos del ejemplo requieren `modelsApproved=true`;
validar versiones, cuotas, modalidad y residencia antes de dar esa confirmación.
`NoAutoUpgrade` evita actualización automática mientras la versión sea soportada;
no evita retiros del servicio.

```bash
./tests/esg-spoke-contracts.sh
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam validate
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam what-if
```

Revisar el what-if y la autorización de la ventana antes de usar `create`. La
fundación crea la Function detenida; no instala código ni ejecuta notebooks.
Las políticas corporativas pueden añadir recursos o modificar configuraciones:
revisar su resultado efectivo antes de activar.

## Red y DNS

Un NSG permite conexiones por origen, destino y puerto; no identifica al usuario
ni analiza contenido. Las reglas propias cierran las entradas/salidas restantes.

- Foundry/Functions acceden a endpoints por HTTPS y a las IP reales de Cosmos
  por TCP 0-65535, necesario para Cosmos en modo directo por Private Link.
- `apiClientPrefixes` solo permite HTTPS hacia `functionPrivateIps`; el NSG no
  abre el resto de endpoints a los usuarios VPN. `operatorPrefixes` permite
  HTTPS administrativo a endpoints y debe limitarse a ejecutores autorizados.
- DNS de plataforma de Azure se permite por puerto 53 y los grupos de cada
  endpoint se asocian a zonas privadas centrales existentes. `monitorPrefixes`
  debe contener los endpoints AMPLS existentes.
- Foundry conserva comunicación interna de su subred, sondas y dependencias AAD,
  MCR, Azure Front Door, Storage y Monitor. Functions permite AAD y Monitor.
- `extraEgress` permite TCP a IPv4/CIDR /24 o más específico, puertos individuales
  y justificación (hasta 140 caracteres). Máximo 100 excepciones; solo subredes
  Foundry/Functions. FQDN se filtra en el firewall CAF, no en NSG.
- Databricks conserva NSG administrados y SCC sin IP pública. Los endpoints
  aceptan desde sus subredes 443, 6666, 3306 y 8443-8451. Revisar reglas efectivas
  del proveedor: su permiso VirtualNetwork puede ser más amplio que el deseado.
  No eliminar reglas administradas ni afirmar microsegmentación completa.
- ADF ejecuta en una VNet administrada separada: los NSG del spoke no controlan
  ese tráfico. Aprobar sus managed endpoints de Storage y Databricks.

La tabla corporativa se conserva en todas las subredes. Confirmar efectos de UDR
sobre endpoints, rutas de retorno, control plane Databricks, dependencias y salidas
externas de scraping. Plataforma crea la conexión al hub de Virtual WAN y valida
el tránsito de VPN; el spoke no crea peerings. No se modifica el firewall corporativo.

Los grupos DNS cubren Foundry/AI, OpenAI, Blob/Queue/Table, Cosmos, App Service
(incluido SCM), ADF y Databricks mediante zonas centrales existentes. DNS
corporativo debe resolverlas desde Azure, VPN y ejecutores. Verificar también
browser_authentication de Databricks para
la región y su propiedad compartida antes de crear otro endpoint equivalente.

## Defender y SIEM

Ambos Storage propios tienen Defender habilitado con herencia de suscripción.
La plantilla no activa planes pagados de toda la suscripción ni sobrescribe su
configuración de análisis. CAF administra planes, límites y exclusiones.
`scanUploads=true` exige comprobar malware scanning en la cuenta de negocio;
no habilita por sí solo el scanner ni bloquea lecturas.

```bash
python3 scripts/check-esg-security.py --resources /ruta/privada/recursos-esg.json
```

El archivo contiene el valor JSON del output `securityResourceIds`. El comando
es de solo lectura: comprueba CloudPosture, AppServices, CosmosDbs, AI y los dos
Storage; devuelve IP de endpoints aprobados para completar `cosmosPrivateIps`
y `functionPrivateIps`. Un error de lectura impide un resultado satisfactorio.
`--no-upload-scanning` solo corresponde a una excepción de riesgo con
`scanUploads=false`; no deshabilita la protección impuesta por CAF.

La presencia de un plan no demuestra cobertura de cada característica:

- Revisar cobertura real de Functions Linux privada y las limitaciones de
  análisis de vulnerabilidades serverless sin acceso a Internet. No abrir la
  aplicación públicamente para satisfacer un scanner.
- Defender for Storage no soporta DBFS root administrado por Databricks. No
  modificar su managed RG ni crear exenciones automáticamente; seguridad debe
  tramitar las exclusiones justificadas. Los Storage propios ESG sí se protegen.
- ADF y Databricks requieren recomendaciones CSPM, permisos/auditoría del servicio
  y controles del proveedor; no son recursos de Defender for Containers.
- No se requieren planes Key Vault o Containers en este spoke mientras esos
  recursos no formen parte del inventario.

El scanner añade recursos administrados, identidad y permisos. Verificar que
DINE/políticas y redeploys no eliminen sus ACL/RBAC. El límite mensual puede dejar
archivos sin analizar. Código y notebooks deben bloquear archivos pendientes,
maliciosos, con error o no analizados, antes de procesarlos. No confiar solo en
etiquetas modificables del blob; acordar señal confiable de resultado con el hub.
El trigger de creación de blob puede llegar antes del resultado: **no se conecta
automáticamente a malware scanning**. Este control sigue pendiente en el código.

Los diagnósticos de recursos se envían a Log Analytics, y opcionalmente a un
Event Hub existente mediante `siemAuthorizationRuleId` y `siemEventHubName`.
Proporcionar ambos o ninguno. La regla es del namespace, compatible con
Azure Monitor (Manage/Send/Listen); no se entrega una clave al Bicep. Verificar
región, firewall, servicios de confianza y permisos del operador.
SOC integra Event Hub/Log Analytics con Taegis y exporta aparte Activity Logs
y alertas Defender. El DDA pide 90 días online y siete años archivados: CAF debe
verificar esa retención; aquí no se modifica el workspace.

## Permisos y activación

La Function exige token Entra para su audiencia y una allowlist de object IDs
`functionAllowedPrincipalIds` (usuarios o identidades de servicio, no grupos ni
client IDs). Para APIM introducir su identidad autorizada una vez exista contrato.
La autorización funcional por roles/datos sigue en la aplicación.

Roles de negocio limitados a `esg-files`, `poc-esg-trigger-data-factory` y `esg-db`.
El host conserva Blob Data Owner en su cuenta exclusiva; Queue y Storage Account
Contributor se activan con `functionUsesBlobTriggers`; Queue/Table con
`functionUsesDurableStorage`. Confirmar bindings antes de reducir permisos.
ADF conserva Contributor únicamente en el workspace Databricks para su conexión
MSI existente; completar entitlements y permiso de adjuntar/reiniciar clúster en
el plano de datos. Revisar esta excepción con el equipo Databricks.

Completar IP reales, rutas y AMPLS; publicar y probar el paquete Function por un
procedimiento privado validado. No se inventa un paquete ni se habilitan claves de
Azure Files. Verificar el mecanismo de despliegue elegido para Linux EP1, sus
requisitos de contenido y el acceso por identidad al host Storage.

Solo tras revisar evidencias, establecer `networkVerified`, `defenderVerified`,
`siemVerified`, `applicationVerified`, `uploadGateVerified` (cuando aplique),
`securityApprovalId`, `actionGroupResourceId` y `activateWorkload=true`.
Los indicadores son declaraciones del operador, no sondas automáticas.
Las pruebas de aplicación previas pueden venir de un entorno de ensayo; repetir
pruebas privadas en destino antes de iniciar triggers/cambiar consumidores.

Alertas de Function: más de 5 respuestas HTTP 5xx en 5 minutos y más de
`functionRequestsAlertThreshold` solicitudes en 5 minutos (inicialmente 10.000).
Se envían al Action Group existente. Ajustar umbrales con mediciones; no equivalen
a una sonda sintética de disponibilidad ni a la medición de tokens de APIM.

## ADF y cambio operativo

Conservar notebooks y clúster de [la entrega Databricks](databricks/README.md).
Desplegar `adf-assets.bicep` con los scripts existentes, ejecutar ambos pipelines
manualmente en entorno controlado y comprobar datos y permisos.

Para iniciar triggers se exige un JSON de constancia con:
`resourceGroup`, `dataFactory`, `approvalId`, `approvedBy`, `approvedAt` (ISO8601
con zona), y valores booleanos true de `networkVerified`, `defenderVerified`,
`siemVerified`, `applicationVerified`, `dataMigrationVerified`,
`pipelineTestsVerified` y `uploadGateVerified` si `scanUploads` no es false.
La constancia corresponde al destino exacto y caduca a los siete días; el script
no comprueba firmas ni genera la evidencia que declara el responsable.

```bash
./scripts/set-esg-adf-triggers.sh RG_ESG FACTORY_ESG start /ruta/privada/evidencia.json
./scripts/set-esg-adf-triggers.sh RG_ESG FACTORY_ESG stop
```

La definición ADF no garantiza detener triggers previamente activos. Verificar
estado real y detenerlos expresamente en la ventana de cambio antes de modificar
assets. Los permisos del operador deben controlar el arranque fuera de estos scripts.

## Migración y límites

No aplicar parámetros de fundación sobre una Function ya operativa: `false`
la detiene. Conservar los indicadores de activación en siguientes despliegues.
Preparar las reglas de red y las IP antes de cerrar NSG de un entorno existente.
Una lista vacía de modelos no elimina modelos desplegados: no es rollback.

ARM incremental conserva asignaciones RBAC omitidas. Inventariar roles heredados
y directos, probar los nuevos alcances y revocar explícitamente permisos anteriores
con el responsable. Cambiar el alcance de una asignación puede exigir reemplazo;
revisar what-if y no declarar mínimo privilegio efectivo hasta completar la retirada.
Conservar datos y RG original; los retrocesos requieren procedimiento explícito.

La redundancia y recuperación siguen pendientes de dimensionamiento por riesgo:
Function EP1 de una instancia, Cosmos serverless en una región sin zona habilitada,
backup continuo 7 días y Storage ZRS con recuperación/versiones 14 días. Probar
restauración, carga, streaming si aplica y el recorrido privado completo.

## Fuentes técnicas verificadas

- [Reglas administradas Databricks](https://learn.microsoft.com/azure/databricks/security/network/classic/vnet-inject).
- [Private Link Databricks](https://learn.microsoft.com/azure/databricks/security/network/concepts/private-link).
- [Autorización Entra de App Service](https://learn.microsoft.com/azure/app-service/configure-authentication-provider-microsoft).
- [Roles de host Functions](https://learn.microsoft.com/azure/azure-functions/functions-identity-based-connections-tutorial).
- [Defender y almacenamiento administrado Databricks](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-storage-false-positive-recommendations).
- [Límites de protección serverless](https://learn.microsoft.com/azure/defender-for-cloud/serverless-protection).
- [Resultados de malware scanning](https://learn.microsoft.com/azure/defender-for-cloud/introduction-malware-scanning).

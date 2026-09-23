# Preparación y despliegue CAF

## Parámetros y responsabilidades

El RG debe existir. Usar una suscripción CAF y región `eastus`. IPAM debe entregar
un bloque RFC1918 /24 sin solapamiento con hub, redes remotas ni clientes VPN.
La plantilla deriva `.0/25`, `.128/26`, `.192/27` y `.224/27`; no reserva espacio
para un firewall ni un gateway VPN local. Una IP web ilustrativa es `.254`.

Entregar `cafClientPrefixes`, `routeTableIds` (claves `foundry`, `containers`,
`appGateway`), `privateDnsZoneResourceIds`, `logAnalyticsWorkspaceId`,
`actionGroupId` y etiquetas `iniciativa`, `OpsDept=DTI` y `UserDept`. Las tablas
deben estar en la región y suscripción de la
VNet y permitir asociación por el operador. No se modifican rutas corporativas.
Plataforma verifica salida por firewall, dependencias Azure, DNS TCP/UDP 53,
Entra ID y rutas de retorno de VPN. Los cuatro NSG limitan conexiones por función
con denegación final. Preparar IP de endpoints, AMPLS y ejecutores siguiendo
[seguridad común y ajustes por solución](SEGURIDAD.md).

La plantilla no crea peerings. En producción, plataforma debe conectar la VNet
al hub de Virtual WAN por el procedimiento corporativo y comprobar rutas de ida y
retorno. Una conexión registrada no prueba por sí sola el acceso desde la VPN.

## DNS y telemetría

Cada endpoint crea su grupo DNS y lo asocia a los IDs de las zonas privadas
centrales entregados por plataforma:

- Foundry: `privatelink.cognitiveservices.azure.com`, `privatelink.openai.azure.com`
  y `privatelink.services.ai.azure.com`.
- Ambos Storage: `privatelink.blob.core.windows.net`.
- Cosmos: `privatelink.documents.azure.com`.
- Search: `privatelink.search.windows.net`.
- ACR: `privatelink.azurecr.io` (incluidos registros de datos regionales).
- Key Vault: `privatelink.vaultcore.azure.net`.

Plataforma publica también el dominio de ACA (`containerEnvironmentDomain`,
registro comodín a `containerEnvironmentIp`) y el nombre web
(`requiredWebDnsName` a `gatewayAddress`) en DNS corporativo. No asumir que DINE
cubra esos registros. DNS de la VNet y de clientes VPN debe alcanzar los
reenviadores/resolvers corporativos. La plantilla no crea zonas DNS privadas.

ACA usa destino `azure-monitor` con diagnóstico a Log Analytics, sin `listKeys`.
Los diagnósticos de servicios y Blob también se envían al workspace existente;
la retención la gobierna CAF, no esta plantilla. La observabilidad de aplicación
se integra con Dynatrace fuera de este Bicep; no se crea Application Insights.

Alertas: backend no saludable del gateway durante 5 minutos y CPU sostenida
superior a 450 millones de nanocores para cada aplicación. Revisar estos umbrales
tras medir carga. El código de aplicación debe instrumentar sus trazas y el
runtime Foundry no configura automáticamente el tracing de conversaciones.

## Aprobaciones comunes

Definir `tags.DataClassification` antes de crear recursos. Proporcionar `modelsApproved=true` únicamente después de confirmar modelo, versión, modalidad, capacidad y residencia. Antes de activar cualquier etapa, registrar un `securityApprovalId` real. Estas condiciones no sustituyen las comprobaciones de red, SIEM, Defender y autenticación que siguen.

## Etapas

1. **Fundación:** todos los indicadores de activación en `false`. Crea red,
   servicios, identidades, endpoints, ACA vacío y observabilidad. Se requieren
   permisos de recursos y asignación de roles. No desplegar modelos no aprobados.
2. **Runtime:** verificar endpoints aprobados, DNS, firewall, conexión de Virtual
   WAN, VPN y RBAC;
   completar `privateServiceAddresses.cosmos`, comprobar Defender y recepción SIEM;
   establecer `defenderCoverageVerified=true`, `siemDeliveryVerified=true`,
   `networkReady=true` y `activateAgentRuntime=true`. La inyección de
   red crea el capability host de cuenta mediante el proveedor; Bicep crea el de
   proyecto y sus conexiones Standard. Comprobar ambos, sin crear un segundo
   host de cuenta. Configurar `models` con nombre, modelo, versión, SKU y capacidad
   positiva autorizados. Sin modelos no se declara operativo el agente.
3. **Imágenes y aplicaciones:** construir y publicar frontend/backend en el ACR
   privado desde un ejecutor conectado a CAF. No abrir el registro. La identidad
   de publicación necesita permisos distintos de `AcrPull`. Registrar digests y
   arquitectura; proporcionar `frontendImage` y `backendImage` con `@sha256:`.
   Puertos predeterminados: 3000/8000. El frontend debe hacer proxy a `BACKEND_URL`;
   validar inicio de sesión Entra, grupos/roles, autorización y rechazo anónimo
   en las imágenes reales. Solo entonces marcar `applicationAuthVerified=true`.
   Completar `monitorPrefixes`, control de archivos (`uploadGateVerified` si
   `scanUploads=true`) y AMPLS; marcar `monitoringReady=true`, después `deployApplications=true`.
   Variables adicionales son solo para valores no secretos. No sobrescribir las
   variables de conexión generadas por la plantilla.
4. **Gateway:** importar PFX con cadena y clave privada en el secreto de certificado
   de Key Vault, preparar hostname/IP y verificar
   `Microsoft.Network/EnableApplicationGatewayNetworkIsolation`. No se registra
   automáticamente esta característica de suscripción. Con DNS y certificado
   listos y con `privateServiceAddresses.vault` descubierto, usar `gatewayReady=true` y `deployGateway=true`. Solo HTTPS; TLS mínimo
   1.2, identidad de gateway y URI de certificado sin versión para renovación.

Los indicadores son declaraciones del operador después de comprobar evidencias,
no son sondas automáticas. ARM rechaza combinaciones de etapas inválidas mediante
un módulo de contratos, incluso sin el comprobador Python. El comprobador añade
validación de IDs, IP, imágenes por digest y modelos. No sustituye el preflight real.

## Validación en Azure y aceptación

Con el contexto de suscripción confirmado y un archivo privado de parámetros:

```bash
python3 scripts/check_parameters.py /ruta/privada/parametros.json
az deployment group validate --resource-group RG_CAF --template-file infra/main.bicep --parameters @/ruta/privada/parametros.json
az deployment group what-if --resource-group RG_CAF --template-file infra/main.bicep --parameters @/ruta/privada/parametros.json
```

Revisar políticas, permisos, cuota/modelos, disponibilidad zonal, rutas y cambios
sobre recursos existentes. Ejecutar `create` únicamente dentro de la autorización
del despliegue. Estos comandos no se ejecutaron como parte de la validación local.

Pruebas: resolución privada desde VNet y VPN; HTTPS y certificado; denegación de
acceso anónimo/no autorizado; frontend inaccesible directamente; backend aislado;
descarga ACR por identidad; lectura/escritura de uploads; ejecución de agente y
persistencia CAF; llegada de logs y disparo de alertas; cargas de archivos,
streaming, concurrencia y restauración. APIM y aceptación corporativa integral
siguen como etapa separada. No se crean agentes, código web ni modelos elegidos
por conveniencia.

Mantener indicadores activados en ejecuciones posteriores. ARM incremental no
elimina recursos omitidos; `false` no es rollback. Para apps usar el digest
anterior y conservar persistencia. Para redes ya ocupadas, preparar otra VNet/RG
y migración explícita; no redimensionar ni borrar la infraestructura original.

## Fuentes verificadas

- [Red de Foundry](https://learn.microsoft.com/azure/foundry/agents/concepts/agents-networking-deep-dive).
- [Ejemplo Standard privado](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup).
- [Gateway privado y aislamiento](https://learn.microsoft.com/azure/application-gateway/application-gateway-private-deployment).
- [Capacidad de subred del gateway](https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure).
- [Disponibilidad de Search](https://learn.microsoft.com/azure/search/search-reliability).
- [Logs ACA](https://learn.microsoft.com/azure/container-apps/log-options).

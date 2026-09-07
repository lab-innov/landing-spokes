# ECOCAF: propuesta de spoke privado

Bicep modular para recrear ECOCAF en **un grupo de recursos nuevo**, con nombres nuevos y migración en paralelo. La base ya compila localmente; no se ha desplegado ni se ha confirmado que represente todas las dependencias de la aplicación.

Validación local del 7 de septiembre de 2026: Bicep 0.42.1 compiló plantilla y parámetros sin diagnósticos. Se comprobaron en el ARM generado los accesos públicos deshabilitados, identidad, parámetros seguros, arranque detenido y ausencia de recursos históricos/DNS central. El recolector pasó pruebas simuladas de respuesta correcta y errores sin revelar el texto de error. No se ejecutaron `validate`, `what-if`, despliegue ni pruebas funcionales en Azure.

## Qué sabemos

La fuente es `main-3.bicep`, un Bicep exportado de 1.395 líneas. Su huella y el inventario por tipo están en [inventario-exportado.json](inventario-exportado.json).

| Evidencia exportada | Tratamiento |
| --- | --- |
| `azfun-POC-ECO-CAF-CR`: Functions Linux, Python 3.13 | Nueva Function App con Functions v4, inicialmente detenida |
| `appsp-poc-eco-caf-cr`: P1v3, una instancia | Nuevo plan Linux P1v3; es App Service Dedicated, no Elastic Premium |
| `rgpocecocafcraf57`: Storage clásico, Standard_LRS | Nueva cuenta StorageV2 Standard_LRS; no actualiza la cuenta original |
| Servicios Blob, File, Queue y Table | Se conserva Blob y se habilita conectividad privada Blob/Queue/Table; no hay evidencia de shares ni colas de aplicación |
| `azure-webjobs-hosts`, `azure-webjobs-secrets` | Contenedores privados vacíos; no copiar claves ni estado del host entre aplicaciones |
| `AzureFunctionsDiagnosticEvents202509` | Tabla histórica: no se recrea ni se migran sus datos automáticamente |
| 23 funciones HTTP | Inventariadas con rutas y métodos; se publican desde el código, no como recursos `sites/functions` |
| 11 registros `sites/deployments` | Historial, excluido de la infraestructura |
| Hostname `azurewebsites.net` | Generado por Azure, sin binding exportado del nombre original |

El historial referencia `Caf-ecocaf-api`, rama `development`, en [Azure DevOps](https://dev.azure.com/CAFrepos/Innovation%20Lab/_git/Caf-ecocaf-api). Es evidencia histórica, no confirmación del repositorio o rama vigentes.

**No aparecen** app settings, cadenas de conexión, código Python, dependencias de paquetes, configuración de autenticación, asignaciones RBAC, bases de datos ni servicios de IA. Su ausencia no demuestra que no se utilicen. La consulta en vivo del 7 de septiembre de 2026 falló con `AADSTS700082` por sesión vencida; no se verificó siquiera el grupo o la suscripción de origen.

## Qué cambia en la propuesta CAF

- VNet nueva con dos subredes: integración Functions delegada a `Microsoft.Web/serverFarms` y private endpoints. CIDRs y DNS obligatorios, pendientes de IPAM.
- NSG por subred, ruta predeterminada al firewall y peering spoke → hub. CAF debe configurar el peering inverso, rutas de retorno y reglas de salida. Los NSG conservan las reglas predeterminadas de Azure: la regla HTTPS no constituye una lista exclusiva de acceso.
- Acceso público deshabilitado en Functions y Storage; endpoint `sites` y endpoints Blob, Queue y Table. No se crean zonas DNS ni zone groups: corresponden a DINE/DNS central de CAF.
- Identidad de sistema para `AzureWebJobsStorage`; roles Blob Data Owner y Table Data Contributor limitados a la cuenta del host. Permisos de otros servicios o futuros triggers requieren revisión específica.
- HTTPS y TLS 1.2, FTP y credenciales básicas SCM deshabilitados, CORS sin comodín.
- Autenticación Entra obligatoria con registro existente y audiencia `api://<clientId>`. Esto es un cambio funcional: los 23 triggers exportados declaran `ANONYMOUS`, aunque puede existir autenticación en el código o una capa externa que no aparece en la exportación. Adaptar los consumidores y validar autorización por usuario/aplicación antes del corte.
- Diagnósticos hacia Log Analytics existente y conexión a Application Insights existente. Son dependencias de plataforma requeridas por el diseño, no recursos encontrados en el archivo. Confirmar su configuración de ingestión, DNS y acceso desde la red CAF.
- StorageV2 sin claves compartidas, sin blobs públicos y con recuperación de blobs/contenedores de siete días. No se provisiona Azure Files: el plan Dedicated no necesita un share para escalado. Si el código o despliegue actual monta shares, deben incorporarse después de verificarlo.

No se añaden Foundry, OpenAI, Cosmos DB, Search, Databricks, ADF, Container Apps, ACR ni Key Vault sin evidencia de que ECOCAF los necesite.

## Errores de exportación

`ExportTemplateCompletedWithErrors` significa exportación parcial. Estos mensajes identifican consultas fallidas, no siete recursos confirmados:

| Tipo omitido | Comprobación pendiente |
| --- | --- |
| `Microsoft.Storage/storageAccounts/inventoryPolicies` | Revisar si existe política de inventario en Storage; recrear solo si corresponde |
| `Microsoft.Web/sites/extensions` | Revisar mecanismo de publicación y extensiones; no reproduce por sí solo el paquete de código |
| `Microsoft.Web/sites/certificates` | Revisar certificados, dominios personalizados y TLS; no copiar material privado al repositorio |
| `Microsoft.Web/sites/siteextensions` | Listar extensiones realmente instaladas y confirmar compatibilidad Linux |
| `Microsoft.Web/sites/sitecontainers` | Revisar configuración de contenedores; `python\|3.13` indica stack Python en la instantánea, no prueba absoluta de ausencia de contenedores |
| `Microsoft.Web/sites/hybridconnection` | Revisar conexiones híbridas y dependencias on-premises |
| `Microsoft.Web/sites/functions/keys` | Revisar consumidores de claves; regenerar para el destino mediante el procedimiento de secretos, sin exportarlas a Git |

## Cerrar el inventario

Después de renovar la sesión con `az login`, ejecutar el recolector de solo lectura, indicando explícitamente la suscripción y el grupo correctos:

```bash
python3 infra/ecocaf-spoke/inventariar.py \
  --subscription '<suscripcion-origen>' \
  --resource-group '<grupo-origen>' \
  --app azfun-POC-ECO-CAF-CR > /tmp/ecocaf-inventario-vivo.json
```

El recolector muestra recursos del grupo, nombres de ajustes y conexiones, autenticación, identidades, funciones, slots y conexiones de red. No imprime valores de ajustes, cadenas de conexión ni claves. Registra consultas fallidas como pendientes; no significa inventario completo cuando alguna falla. Su alcance es el grupo indicado y metadatos de la app, no toda la suscripción o el plano de datos.

Completar con estas revisiones:

1. Consultar valores de configuración en un entorno autorizado sin pegarlos en chats ni versionarlos. Relacionar cada endpoint/cuenta/URI de Key Vault con su recurso, grupo, suscripción, permisos y propietario; incluir servicios externos.
2. Revisar `function_app.py`, `requirements.txt`, `host.json` y el pipeline vigente: clientes de SDK, llamadas HTTP, SQL/Cosmos/Storage, recursos con nombres fijos y credenciales. Los nombres de rutas como `Model`, `kpis` o `documents` no identifican el proveedor usado.
3. Revisar slots, diagnósticos, RBAC heredado, Application Insights y dependencias observadas en ejecución. Revisar por separado los siete tipos omitidos y configuración de dominios/certificados.
4. Confirmar frontend y consumidores, autenticación actual, datos a migrar, capacidad P1v3 disponible en la suscripción destino y política de publicación desde la red privada.

## Parámetros y validación

[main.bicep](main.bicep) es el punto de entrada, a nivel de grupo de recursos. [main.bicepparam](main.bicepparam) es un ejemplo con valores `PENDIENTE`, intencionalmente no desplegable. Preparar una copia local fuera del repositorio o inyectar parámetros seguros desde el pipeline.

IPAM debe asignar rangos sin solapamiento; planificar al menos `/26` para integración y `/27` para endpoints como reserva inicial a confirmar, no como asignación aprobada. DNS central debe resolver `privatelink.azurewebsites.net` (app y SCM), `privatelink.blob.core.windows.net`, `privatelink.queue.core.windows.net` y `privatelink.table.core.windows.net`, con sus enlaces y rutas desde el spoke y desde el agente de publicación.

```bash
az bicep build --file infra/ecocaf-spoke/main.bicep --outfile /tmp/ecocaf-template.json
az bicep build-params --file infra/ecocaf-spoke/main.bicepparam --outfile /tmp/ecocaf-parametros-ejemplo.json
# Solo con parámetros reales, sin PENDIENTE, y un grupo destino nuevo:
az deployment group what-if --subscription '<suscripcion-destino>' \
  --resource-group '<grupo-nuevo>' \
  --template-file infra/ecocaf-spoke/main.bicep \
  --parameters '@/ruta/local/parametros-reales.json'
```

`applicationSettings` representa el conjunto completo de ajustes específicos de aplicación: una actualización reemplaza la colección. No incluir `AzureWebJobsStorage` ni variantes de este prefijo, secretos literales versionados, ni ajustes de contenido/paquete heredados sin comprobar su compatibilidad. La plantilla fija los ajustes básicos del runtime y la conexión por identidad. Las referencias a Key Vault requieren que ese vault exista y que se configuren explícitamente su red y permisos.

## Migración y verificación funcional

1. Cerrar inventario, aprobar IPAM, nombres nuevos, acceso Entra y conectividad CAF. Revisar `what-if`; no apuntar esta plantilla al grupo actual.
2. Desplegar en modo incremental con `activateFunctionApp = false`. Este valor no detiene el cobro del plan P1v3.
3. Esperar DINE/DNS, aprobación de private endpoints, peering inverso, firewall y propagación RBAC. Verificar desde una máquina o agente dentro de la red privada la resolución de app, SCM, Blob, Queue y Table.
4. Recuperar y adaptar el código y configuración verificados, preparar el paquete Python 3.13 y publicarlo con autenticación Entra desde el agente privado. La compilación Bicep no publica `function_app.py` ni prueba compatibilidad de sus paquetes.
5. Migrar únicamente los datos de aplicación identificados, con copia y permisos propios. No copiar claves ni leases del host original. Si la app comparte datos externos, no dirigirla a producción antes de controlar sus efectos de escritura.
6. Activar la app de destino de forma controlada y probar host, almacenamiento, telemetría y las 23 rutas con datos de prueba; comprobar 401 sin token y acceso correcto de consumidores autorizados. Verificar que las solicitudes públicas fallen.
7. Cambiar consumidores solo después de aceptación. Conservar origen y su configuración para reversión; documentar reconciliación de datos si hubo escrituras en el destino. Este repositorio no ejecuta el corte ni borra el origen.

## Referencias

- [Limitaciones de exportación de plantillas](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/export-template-portal).
- [Red de Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options).
- [Conexiones por identidad administrada](https://learn.microsoft.com/en-us/azure/azure-functions/manage-connections).
- [Configuración de Functions y requisitos de contenido por plan](https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings).

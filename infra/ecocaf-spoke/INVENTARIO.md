# Inventario y migración ECOCAF

Evidencia histórica del 7 de septiembre de 2026. No se renovó la consulta Azure
en esta revisión. La seguridad actual se documenta en [SEGURIDAD.md](SEGURIDAD.md).

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

## Evidencia funcional adicional

La guía de despliegue del 28 de junio de 2025 y el documento técnico V2 del 4 de
abril de 2025 se revisaron como documentación de la aplicación, no como instrucciones
de Landing Zone ni como autorización de despliegue.

El documento técnico coincide con rutas observadas en la exportación y confirma el
flujo funcional de ECOCAF: el frontend carga documentos PDF, `uploadDocuments` los
guarda en Blob Storage, `extract_fields` extrae variables, `Model` realiza el análisis
con un modelo de Azure OpenAI y `insertProyect` persiste o actualiza proyectos por
fase en Cosmos DB. También describe consultas para KPI, historial y fases. Esto eleva
Blob de negocio, Cosmos DB, Azure OpenAI, Document Intelligence y el frontend de
“dependencias posibles” a “dependencias funcionales documentadas”.

La guía menciona además App Service, Data Factory y Databricks. Sin embargo, mezcla
nombres de iDataFactory, IFISCAF y Vinculador y propone exportación/importación manual
genérica. Por ello no demuestra nombres, SKU, redes, pipelines, notebooks ni contratos
de datos propios de ECOCAF y no se copiará literalmente al Bicep.

La documentación técnica muestra acceso histórico a Cosmos mediante endpoint y clave.
El destino CAF debe migrarlo a identidad administrada y RBAC de datos, o registrar una
excepción explícita; no se incorporarán claves al repositorio ni a parámetros normales.

**No aparecen en la exportación** app settings, cadenas de conexión, código Python,
dependencias de paquetes, configuración de autenticación, asignaciones RBAC ni los
recursos funcionales externos documentados. La consulta en vivo del 7 de septiembre
de 2026 falló con `AADSTS700082` por sesión vencida; no se verificó siquiera el grupo
o la suscripción de origen.

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
5. Recuperar el contrato real de Blob, Cosmos, OpenAI y Document Intelligence:
   cuentas, grupos, base de datos, contenedor, clave de partición, contenedores Blob,
   modelos/versiones, identidades y roles. Confirmar si ADF y Databricks pertenecen a
   ECOCAF o son referencias mezcladas de otras soluciones antes de crearlos.

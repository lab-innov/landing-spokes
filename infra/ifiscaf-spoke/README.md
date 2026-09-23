# Spoke seguro de IFISCAF

Se crea un grupo de recursos paralelo en East US. La conexión al hub corporativo
de Virtual WAN queda a cargo de plataforma.
Se conserva `RG-POC-IFIS-CR` para revertir la migración.

## Recursos

- VNet, NSG por subred y tabla de rutas corporativa; sin peering creado por el spoke.
- Subred de Private Endpoints, integración de Functions y dos subredes dedicadas
  a Databricks de /26 o mayores.
- Azure OpenAI con `gpt-4o-batch` parametrizable y Document Intelligence.
- ADLS Gen2 con `source` y `sypdocuments`; Storage separado para Functions.
- Cosmos NoSQL `IfisCAF/Reportes`, partición `/id`, 400 RU/s, East US/West US,
  consistencia Session y free tier deshabilitado. La réplica no constituye un
  plan de recuperación regional de toda la aplicación.
- Function App Linux P1v3, Python 3.13, identidad administrada, Entra, entrada
  privada y salida integrada en la VNet.
- Databricks Premium, nodos sin IP pública, access connector y endpoints privados
  de API/autenticación web. `AllRules` requiere salida corporativa aprobada para
  el plano de control; no implica aislamiento total de ese plano.
- Data Factory con VNet administrada y endpoints administrados.
- Diagnósticos en Log Analytics; Dynatrace se integra fuera de este Bicep.
- Endpoint privado al Storage compartido y `Storage Blob Data Reader` limitado
  a su contenedor para el access connector.

No se despliega Microsoft Foundry.

## Requisitos de plataforma

Infraestructura proporciona tabla de rutas, IDs de zonas DNS privadas centrales,
Log Analytics, tenant/aplicación Entra, etiquetas CAF y CIDR aprobados por IPAM.
Los rangos de ejemplo no son asignaciones autorizadas. Debe crear la conexión de
Virtual WAN y aprobar la salida por firewall, incluyendo servicios de Azure,
Databricks y bibliotecas.

DNS Private Resolver administra las zonas centrales; cada endpoint de este
despliegue crea su grupo DNS, pero no una zona. Se requieren las zonas privadas de OpenAI, Cognitive Services,
Blob, DFS, Queue, Table, Cosmos, Azure Websites, Data Factory/ADF y Databricks.
DNS debe cubrir también los endpoints regionales de Cosmos.

La plataforma coordina Dynatrace, aprueba los endpoints de ADF y del Storage
compartido y autoriza al desplegador a asignar roles en el
contenedor compartido. El operador que activa triggers necesita
`Microsoft.EventGrid/eventSubscriptions/write` en ambos Storage. Verificar
además la comunicación Storage/Event Grid.

La capacidad exportada `60009` es un dato de origen, no una reserva de cuota.
Validar disponibilidad, capacidad libre y políticas heredadas antes de crear recursos.

## Etapas

Completa los ejemplos de `environments/ifiscaf-spoke`:

```bash
./scripts/deploy-ifiscaf-spoke.sh environments/ifiscaf-spoke/dev.bicepparam validate
./scripts/deploy-ifiscaf-spoke.sh environments/ifiscaf-spoke/dev.bicepparam what-if
./scripts/deploy-ifiscaf-spoke.sh environments/ifiscaf-spoke/dev.bicepparam create
```

Publica notebooks y clúster siguiendo la [entrega de Databricks](databricks/README.md).
Con sus salidas completa los parámetros de ADF:

```bash
./scripts/deploy-ifiscaf-adf-assets.sh rg-ifiscaf-secure-spoke-dev environments/ifiscaf-spoke/adf-dev.bicepparam validate
./scripts/deploy-ifiscaf-adf-assets.sh rg-ifiscaf-secure-spoke-dev environments/ifiscaf-spoke/adf-dev.bicepparam what-if
./scripts/deploy-ifiscaf-adf-assets.sh rg-ifiscaf-secure-spoke-dev environments/ifiscaf-spoke/adf-dev.bicepparam create
```

Se preservan `ProcesoIFISCAF`, su rama de fallo `UpdateCosmosOnFail`,
`ProcesoDataSintetica` y los filtros originales. Los parámetros `anio` y
`pathjson` reciben `@triggerBody().folderPath`; comprobar ese contrato con los
notebooks. Los nuevos triggers se crean detenidos.

Después de migrar datos/código y validar, coordina la parada del trigger antiguo
sobre el contenedor compartido para evitar procesamiento doble:

```bash
./scripts/set-ifiscaf-adf-triggers.sh rg-ifiscaf-secure-spoke-dev <factory-name> start
```

Usa `stop` en el nuevo factory para revertir. La parada/reactivación del factory
original se coordina por separado. Reconcilia las escrituras posteriores al
cambio antes de devolver tráfico al sistema original.

## Contrato de aplicación

| Configuración nueva | Uso |
| --- | --- |
| `AzureWebJobsStorage__accountName` | Storage del host con identidad |
| `BLOB_STORAGE_ACCOUNT_URL` | Endpoint Blob de IFISCAF |
| `BLOB_STORAGE_CONTAINER_NAME` | `sypdocuments` |
| `BLOB_STORAGE_SOURCE_CONTAINER_NAME` | `source` |
| `COSMOS_DB_ENDPOINT` | Endpoint Cosmos |
| `COSMOS_DB_DATABASE` / `COSMOS_DB_CONTAINER` | `IfisCAF` / `Reportes` |
| `AZURE_OPENAI_ENDPOINT` / `AZURE_OPENAI_DEPLOYMENT` | Servicio y modelo |
| `DOCUMENT_INTELLIGENCE_ENDPOINT` | Servicio de extracción |

El código debe usar `DefaultAzureCredential` o credenciales equivalentes de Entra.
No restaurar claves ni las antiguas cadenas de conexión. Las dependencias de
auditoría y Cosmos de logging externos deben confirmarse antes de cambiar tráfico.
GlobalBatch requiere operaciones batch; no sustituye una API síncrona.

El access connector no proporciona automáticamente `DefaultAzureCredential` al
código del clúster. Configurar credenciales de servicio de Unity Catalog o una
identidad de ejecución con acceso a OpenAI, Document Intelligence y Cosmos en la
etapa de aplicación.

## Validación y límites

```bash
./tests/ifiscaf-spoke-contracts.sh
```

Antes de activar triggers, verificar endpoints aprobados, DNS privado, rutas y
rechazo de acceso público. Desde la red privada, Functions debe devolver 401 sin
token y aceptar al cliente Entra autorizado. Comprobar arranque del host sin
claves y acceso de la aplicación mediante identidad.

Iniciar Databricks sin IP pública, ejecutar los tres notebooks y ambos pipelines
con MSI, incluida la rama Failed. Probar los filtros de BlobEvents y sus parámetros,
confirmar diagnósticos en Log Analytics y reconciliar blobs/documentos.

Código de Functions, notebooks, clúster, permisos de datos de Databricks, copias
de datos y configuración central de red pertenecen a etapas separadas.
Se excluyen snapshots, historial de despliegue, roles/políticas integrados,
tablas temporales y el webhook opaco del export.

La compilación local no acredita cuota, permisos, políticas ni conectividad.
La validación y what-if de Azure requieren parámetros corporativos reales.

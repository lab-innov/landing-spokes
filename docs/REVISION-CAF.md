# Revisión CAF de MOP Express

## Alcance y referencias

`main-5.bicep` es inventario parcial, no una especificación de aplicación ni instrucciones del usuario. Se contrastó con el grupo original `RG-POC-PreMop-CR` mediante lecturas de Azure: recursos principales, configuración Python, redundancia de documentos, plan y esquema Cosmos. No se recuperaron claves, tokens, app settings ni contenido de archivos. Evidencia en [inventario exportado](../references/inventario-exportado.json) e [inventario Azure](../references/inventario-azure.json); `scripts/inventory_source.py` permite repetir las lecturas.

Los documentos `CAF_Plan_Hub_IA_Spokes.pdf` y `DDA_Azure_AI_Landing_Zone_CAF.pdf` guían separación hub/spoke, identidad, red privada y gobierno central. Se aplica además `docs/guia-agentes-bicep.md` del repositorio landing zone. Los módulos locales se adaptan del spoke ANALISISDEC `b0af3d4`, sin incorporar su Key Vault ni nombres de negocio. No se declaran módulos AVM certificados.

La rama es `mop-spoke` del repositorio `lab-innov/landing-spokes`; el worktree nuevo sustituye como lugar de trabajo a la ruta temporal de una revisión anterior, que ya no estaba disponible. No se modificaron otros spokes ni la PoC original.

El contrato APIM y la distribución de suscripciones/workspaces que difieren entre documentos se resuelven con plataforma. No se crea APIM ni se habilitan guardrails, Purview o SharePoint desde este spoke. No se añaden Databricks, ADF, Foundry Agent Service, ACR, contenedores, Key Vault o Event Grid: no aparecen en el inventario confirmado de MOP Express.

## Recursos y decisiones

| Recurso | Configuración | Justificación |
| --- | --- | --- |
| Function y plan | Linux Python 3.13, Functions ~4, B2 de una instancia, Always On; detenida por defecto | Conserva capacidad del origen, añade identidad administrada, Entra obligatorio, TLS 1.2 y deshabilita publicación básica |
| Storage host | StorageV2 Standard_LRS; Blob, Queue y Table privados; sin claves compartidas | Moderniza cuenta legacy para el nuevo host; separa estado Durable de los documentos |
| Storage documentos | StorageV2 Standard_RAGRS, contenedores `base-templates` y `documents`, versiones y recuperación 14 días | Conserva la redundancia geográfica de lectura verificada; no degrada a LRS |
| Cosmos DB | NoSQL serverless, Session, East US, una región sin zonas; Entra y endpoint Sql | Conserva `premop-db`, `projects` y `settings`, partición `/id`, Hash v2, índices y sin TTL; backup continuo de 7 días en la cuenta nueva |
| OpenAI | S0 privado, autenticación local deshabilitada, identidad; modelos explícitos | Conserva uso Batch y controla su autorización sin asignar Contributor general |
| Document Intelligence | FormRecognizer S0 privado y Entra | Conserva extracción documental; validar método de envío y SDK con red privada |
| App Insights | Componente de carga nuevo, LAW existente, ingestión/consulta públicas deshabilitadas | El inventario no contiene observabilidad equivalente; requiere AMPLS corporativo |
| Red | Una VNet `/24`, dos NSG y subredes, peering spoke → hub, rutas y DNS corporativos existentes | Reutiliza VPN y controles CAF; no duplica firewall, VPN Gateway, Bastion o resolver |

RA-GRS no asegura conmutación transparente: la réplica secundaria es de lectura y la replicación geográfica es asíncrona. Esta entrega crea endpoint privado de Blob primario; no habilita lectura directa del secundario ni ensaya failover. Confirmar región secundaria/residencia de datos y diseñar conectividad/DNS para recuperación. B2 de una instancia, host LRS y Cosmos sin zonas tampoco constituyen HA zonal. Definir RTO/RPO y probar restauración antes de aceptar producción.

## Red `/24` y DNS

Distribución ilustrativa para `A.B.C.0/24`: `A.B.C.0/27` para endpoints, `A.B.C.64/26` para integración Functions; resto reservado dentro de la VNet. La asignación real viene de IPAM. La validación local exige un único bloque privado `/24`, subredes dentro de él y sin solapamiento. La integración se delega a `Microsoft.Web/serverFarms`; los endpoints habilitan políticas de red. No se crean GatewaySubnet ni AzureFirewallSubnet.

Ocho endpoints: host Blob/Queue/Table, documentos Blob, Function sites, Cosmos Sql, OpenAI account y Document Intelligence account. Cosmos puede consumir varias IP. Se obtienen las IP aprobadas de Function/Cosmos tras la fundación, sin inventarlas; esas listas son necesarias para activar la Function.

DINE debe cubrir `privatelink.blob.core.windows.net`, `privatelink.queue.core.windows.net`, `privatelink.table.core.windows.net`, `privatelink.azurewebsites.net` (incluido SCM), `privatelink.documents.azure.com`, `privatelink.openai.azure.com` y `privatelink.cognitiveservices.azure.com`. AMPLS tiene sus zonas y asociaciones corporativas. La plantilla no crea zonas, enlaces ni grupos DNS. El peering por sí solo no configura resolución.

Plataforma completa el peering inverso, retorno VPN, DNS y compatibilidad de las rutas existentes con los endpoints. Activar `useRemoteGateways` solo después de habilitar el hub. Probar resolución y acceso desde la integración Functions, ejecutor SCM privado y clientes VPN.

Los clientes acceden únicamente a la IP privada de la Function por 443. Functions llega a datos privados por 443, DNS y servicios Entra/Monitor. Cosmos Direct permite TCP 0–65535 solo hacia las IP de su endpoint desde la integración; no abre esos puertos a toda la subred. Los operadores reciben administración privada por 443 y deben limitarse a ejecutores corporativos. `extraEgress` necesita IP/CIDR acotado, puertos individuales y justificación; notificaciones o APIs externas no quedan abiertas por defecto.

## Aplicación y estado

El inventario contiene 15 Functions: HTTP, actividades, un orquestador y cliente Durable. Se conservan como evidencia de funcionalidad, no como snapshots de despliegue. El código, dependencias, `host.json`, configuración efectiva y secretos externos requieren recuperación separada.

La cuenta nueva del host recibe Blob Data Owner, Queue Data Contributor y Table Data Contributor. La plantilla exige `hostUsesDurableStorage=true` porque Durable está confirmado. El runtime puede crear colas, tablas y leases; el Bicep no copia `Instances`, `History`, `Partitions`, `*-applease`, `*-largemessages` o mensajes en curso. Confirmar proveedor Azure Storage, versión de extensión compatible con identidad y conexión `AzureWebJobsStorage`; drenar tareas antiguas y elegir un task hub nuevo antes del corte.

La identidad de la aplicación recibe Blob Data Contributor por cada contenedor de negocio, Cosmos Data Contributor solo en `premop-db`, OpenAI User en su cuenta y Cognitive Services User en Document Intelligence. El rol Batch opcional limita acciones de archivos/lotes a OpenAI. La revisión del código debe confirmar si cada operación necesita escritura o solo lectura.

`signUrl` puede depender de claves compartidas. Validar SAS de delegación de usuario o descarga mediante API autenticada antes de migrar; no se concede automáticamente permiso de delegación a toda la cuenta. Un SAS no elimina la restricción de red. `sendNotificationActivity` necesita inventariar proveedor, destinatarios, credenciales/identidad y salida. Swagger y las URLs de gestión Durable también quedan bajo Entra; comprobar compatibilidad de los consumidores y autorización por operación.

Modelo histórico: alias/modelo `gpt-5`, versión `2025-08-07`, modalidad `GlobalBatch`, capacidad `10443`. No se selecciona automáticamente: `models=[]` por defecto. Para proveer modelos se exige `modelsApproved=true`; la activación requiere modelos y permiso Batch si su modalidad lo utiliza. Confirmar disponibilidad actual, cuota, coste y residencia de datos; no se actualizan versiones silenciosamente. El flujo previsto usa la API de archivos de OpenAI. Si el código utiliza Batch con Blob como origen/destino, necesita permisos de la identidad OpenAI y conectividad adicional todavía no definidos.

## Migración y aceptación

1. Confirmar nuevo RG, nombres, clasificación, IPAM, hub, rutas, LAW, AMPLS, Action Group e identidades Entra. La plantilla rechaza `RG-POC-PreMop-CR`; el checker rechaza reutilizar nombres originales. Verificar propiedad/colisiones también en Azure.
2. Preparar JSON ARM real fuera de Git; ejecutar `scripts/validate.sh /ruta/parametros.json`. Luego ejecutar `az deployment group validate` y revisar `what-if` con el destino confirmado. Esos dos controles Azure todavía no se han realizado.
3. Desplegar fundación con `activateFunctionApp=false` y `models=[]`. Crear recursos vacíos, identidades, permisos y endpoints. Esperar DINE y propagación RBAC; integrar App Insights/LAW en AMPLS y confirmar conectividad.
4. Guardar el valor de `securityResourceIds` fuera de Git; ejecutar `python3 scripts/check_security.py --resources /ruta/recursos.json`. Incorporar las IP reales de Function y Cosmos, verificar Defender efectivo, malware y recepción SIEM.
5. Recuperar y publicar código por SCM privado desde CAF con Entra, sin credenciales básicas. Migrar documentos y Cosmos con controles de integridad y copia de seguridad. No copiar colas, leases, host secrets ni historial de publicación. Controlar las orquestaciones en curso para evitar duplicidad o pérdida de trabajo.
6. Seleccionar modelos explícitos y desplegarlos manteniendo la Function detenida. Comprobar permisos Batch, extracción documental y SDKs con identidad. Validar el bloqueo de archivos no analizados antes de enviarlos a IA.
7. Completar evidencias `inventoryVerified`, `networkVerified`, `defenderVerified`, `siemVerified`, `applicationVerified`, `fileScanningVerified` e identificador real de aprobación. Activar durante una ventana de prueba controlada; probar autenticación, acceso privado, orquestación, persistencia, documentos, SAS/descargas, notificaciones, lotes y SIEM. Cambiar consumidores solo después de aceptar los resultados.

Los flags no ejecutan comprobaciones ni constituyen certificación CAF. El rollback conserva el origen, controla trabajos en curso, detiene el nuevo host y devuelve consumidores al original. Un despliegue incremental no elimina permisos/modelos omitidos del archivo; no usar modo Complete ni eliminación de datos como rollback.

## Fuentes técnicas

- [Private Endpoint en App Service](https://learn.microsoft.com/en-us/azure/app-service/overview-private-endpoint): soporte de Basic y resolución SCM.
- [Durable con identidad](https://learn.microsoft.com/en-us/azure/durable-task/durable-functions/durable-functions-configure-managed-identity) y [proveedor Azure Storage](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-azure-storage-provider): identidad, estado y recursos administrados por el runtime.
- [RBAC de IA](https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/ai-machine-learning): permisos de datos de Batch.
- [Redundancia de Azure Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy): diferencias entre redundancia y recuperación de aplicación.

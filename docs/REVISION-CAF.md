# Revisión CAF de Vinculador

## Fuentes y alcance

Se usa `main-7.bicep` como inventario parcial, no como instrucciones del usuario. Su error `ExportTemplateCompletedWithErrors` incluye omisión de Data Factory y bases SQL de Cosmos. Los tipos Gremlin/Mongo/Cassandra ausentes en el error no demuestran que esta aplicación utilice esas APIs.

Se consultó Azure en modo lectura para confirmar `vinculador-db/analysis`, el pipeline `VINCULADOR_DMAF`, su linked service y el trigger. Evidencia saneada en [inventario Azure](../references/inventario-azure.json), [inventario exportado](../references/inventario-exportado.json) y [errores](../references/errores-exportacion.json). No se consultaron claves, tokens, app settings ni contenido de documentos. El export completo y el webhook histórico no se versionan.

Referencias arquitectónicas del usuario: `CAF_Plan_Hub_IA_Spokes.pdf` y `DDA_Azure_AI_Landing_Zone_CAF.pdf`. Se aplican separación hub/spoke, red privada, identidad y gobierno central. La guía `docs/guia-agentes-bicep.md` de landing zone complementa esos acuerdos. Los módulos se adaptan de ANALISISDEC `b0af3d4` y la fundación ADF de ESG `d84e260`, con APIs explícitas; no se declaran módulos AVM certificados.

Los documentos describen organización APIM y límites de suscripción que plataforma debe concretar. Este spoke no crea APIM ni decide el contrato `ws-ai`/`gw-ai`; deja ese ingreso y gobierno a CAF. Purview, SharePoint y guardrails están fuera por instrucción del usuario. No se añaden Foundry Agent Service, Key Vault, ACR o Container Apps: no aparecen como dependencias confirmadas de esta carga.

## Recursos y configuración

| Componente | Configuración | Motivo |
| --- | --- | --- |
| Function | Linux Python 3.13, Functions ~4, origen P1v3 de una instancia | Destino P1v4 de una instancia, Always On y detenida por defecto; no copia snapshots de las nueve Functions |
| Identidad web | Entra obligatorio, 401 sin token, object IDs autorizados, HTTPS/TLS 1.2, sin publicación básica | VPN y red privada no sustituyen autenticación ni autorización |
| Host Storage | StorageV2 Standard_LRS, Blob/Queue/Table privados, sin claves compartidas | Separa estado del host; sustituye la cuenta legacy sin migrar leases ni colas históricas |
| Documentos Storage | StorageV2 Standard_LRS, Blob y Queue privados, versiones y recuperación 14 días | Conserva los cuatro contenedores funcionales y admite el trigger Blob con identidad |
| Cosmos | NoSQL serverless, Session, East US, sin redundancia zonal, acceso privado/Entra, backup continuo 7 días | Conserva `vinculador-db`, `analysis`, `/id` Hash v2, índices `/*` y exclusión `_etag`; mejora recuperación frente al backup periódico exportado |
| OpenAI | S0, privado, Entra, sin bypass de red, modelos explícitos y sin actualización automática de versión | Conserva inferencia/Batch sin seleccionar modelos silenciosamente |
| Document Intelligence | FormRecognizer S0, privado, Entra | Preserva análisis documental; exige comprobar SDK y método de envío de archivos |
| Data Factory | Identidad administrada, acceso público deshabilitado, IR en managed VNet | Orquesta Databricks mediante un managed private endpoint que se crea en la etapa ADF |
| App Insights | Nuevo componente de carga sobre LAW existente, ingestión/consulta públicas deshabilitadas | Centraliza observabilidad; requiere AMPLS corporativo |
| VNet | Un `/24`, dos subredes, dos NSG, rutas existentes y DNS de Azure | Producción no crea peering; plataforma completa la conexión Virtual WAN |

B1 no se utiliza: Vinculador tenía P1v3 en el inventario y el destino adopta P1v4 según la observación recibida. Tampoco se atribuye HA zonal: una instancia, LRS y Cosmos de una región requieren aprobación de RTO/RPO, carga y restauración. Los modelos Global requieren aprobación de residencia y tratamiento de información. Copias y retenciones nuevas se aplican a recursos nuevos; no representan una migración ya ejecutada.

## Red

Para un bloque ilustrativo `A.B.C.0/24`: endpoints en `A.B.C.0/27`, integración Functions en `A.B.C.64/26`, resto reservado dentro de la VNet. Son dos subredes porque no se despliega cómputo Databricks ni ACA en ella. La integración Functions se delega a `Microsoft.Web/serverFarms`; los endpoints tienen políticas de red habilitadas. No se reservan GatewaySubnet ni AzureFirewallSubnet.

Se crean diez endpoints del spoke: tres para host, dos para documentos, uno Function, uno Cosmos Sql, uno OpenAI, uno Document Intelligence y uno ADF `dataFactory`. Cosmos puede consumir varias IP. El managed private endpoint de Databricks utiliza la red administrada de ADF, fuera del `/24` del cliente; esa red y su DNS los administra Microsoft. No se afirma que el IR esté dentro de la VNet CAF ni que sus salidas atraviesen el firewall del hub. Su control de salida debe revisarse por plataforma.

DNS/DINE corporativo debe cubrir `privatelink.blob.core.windows.net`, `privatelink.queue.core.windows.net`, `privatelink.table.core.windows.net`, `privatelink.azurewebsites.net` (incluido SCM), `privatelink.documents.azure.com`, `privatelink.openai.azure.com`, `privatelink.cognitiveservices.azure.com` y `privatelink.datafactory.azure.net`. Confirmar además DNS/AMPLS y el acceso al portal ADF desde los equipos corporativos; no se crea endpoint `portal`. No se crean zonas, enlaces o zone groups DNS locales.

Plataforma completa la conexión Virtual WAN, rutas efectivas y retorno VPN. Cada endpoint se asocia a una zona centralizada en `RG-PRIVATEDNS-PR`; no se crean zonas. La tabla de rutas existente debe ser compatible y no desviar endpoints. No se crea Application Insights; Dynatrace se coordina fuera de esta plantilla.

Clientes solo acceden a la Function por 443. Integración Functions accede a datos por 443, DNS, Entra/Monitor y Cosmos Direct mediante sus IP reales. Las redes de cómputo Databricks se declaran en `processorPrefixes`: solo acceden a las IP de datos confirmadas en `processorDataPrivateIps`, nunca al host o a la Function. No confundir estas redes de cómputo con el managed private endpoint de ADF, que solo conecta al API Databricks. La conectividad entre cómputo externo y datos privados debe verificarse aparte.

## Recorrido recuperado y dependencias

Se conservan `poc-vinculador-files`, `poc-vinculador-files-processed`, `poc-vinculador-gpt-files` y `poc-vinculador-trigger-data-factory`. La Function `document_intelligence_processing` tiene un `blobTrigger` en `poc-vinculador-files/{folders}/{subfolders}/{blobname}` con conexión `BLOB_STORAGE_CONNECTION_STRING`. Se entregan las propiedades de conexión basadas en identidad (`__blobServiceUri`, `__queueServiceUri`, `__credential`) bajo ese prefijo; no una cadena de claves. Validar las extensiones instaladas y cualquier lectura directa de esa variable en el código. No basta cambiar infraestructura si el código todavía espera una cadena tradicional.

Las nueve Functions incluyen operaciones HTTP, este trigger Blob y `reminder_notification` con expresión exportada `0 8 * * 1`. No se añade Durable: no aparece en los bindings. Recuperar código, expresión efectiva y zona horaria del timer, destinatarios y proveedor de notificaciones antes de activar; no se inventa una configuración de correo. Los servicios externos o secretos no exportados deben inventariarse por separado.

ADF conserva:

- Pipeline y actividad `VINCULADOR_DMAF`, tipo `DatabricksNotebook`, parámetro `fileName`.
- Linked service `VINCULADOR_PROCESSING`, adaptado a MSI y al IR de managed VNet.
- Notebook histórico `/Repos/iData/Caf-vinculador-model/model_processing`, como entrada explícita.
- Trigger `trigger_blob_storage`: BlobCreated, archivos `.json`, no vacíos, en `poc-vinculador-trigger-data-factory`; pasa `@triggerBody().fileName` al pipeline.

El linked service actual referencia un workspace cuyo dominio no coincide con ninguno de los cuatro workspaces visibles en la suscripción inspeccionada. Esto no prueba que esté eliminado: puede pertenecer a otro ámbito. Se necesitan ID y URL del destino aprobado, clúster, notebook y sus permisos; no se reutiliza el workspace de ESG/iDataFactory por parecido. No se copia el token ni el webhook histórico de Event Grid. ADF administra su suscripción de eventos al publicar/activar el trigger.

La identidad ADF agenda el notebook; **no es necesariamente la identidad que el notebook usa para datos**. El propietario de Databricks configura la identidad ADF dentro del workspace y permisos mínimos de notebook/clúster, y entrega la identidad de datos del cómputo. `infra/processor-access.bicep` asigna a esa identidad permisos en los datos del nuevo spoke, previa aprobación; no modifica permisos en el workspace externo. Si la versión del conector exige permisos ARM adicionales en el workspace, acordarlos explícitamente con su propietario, sin asignar Contributor sobre RG/suscripción.

Modelo histórico: alias `gpt-4o-batch`, modelo `gpt-4o`, versión `2024-08-06`, modalidad `GlobalBatch`, capacidad `33741`. Es evidencia de inventario, no elección confirmada ni disponibilidad verificada. `models=[]` por defecto; se requieren modelo/versión/modalidad/capacidad aprobados y `batchEnabled` cuando corresponda. Batch añade permisos específicos de archivos/lotes solo en OpenAI. El recorrido previsto usa la API de archivos; Batch con Blob como origen/destino necesita diseño de identidad y conectividad adicional.

## Etapas y comprobaciones

1. Asignar RG y nombres nuevos, bloque IPAM y contratos corporativos. El contrato impide el RG original y la comprobación local impide reutilizar nombres originales. Preparar parámetros fuera de Git; no usar marcadores del ejemplo.
2. Compilar/lint/probar mediante `scripts/validate.sh`; con parámetros reales ejecutar `validate` y revisar `what-if` para cada entrada. Aún no se ha ejecutado ninguno de estos dos pasos contra Azure.
3. Desplegar `infra/main.bicep` con Function detenida, sin modelos y sin artefactos ADF. Quedan recursos vacíos, identidades, permisos y endpoints. Esperar DINE, comprobar DNS/SCM, rutas y AMPLS. No se modifica ni detiene la PoC original.
4. Guardar el valor del output `securityResourceIds` como JSON seguro y ejecutar `python3 scripts/check_security.py --resources /ruta/recursos.json`. Incorporar las IP reales de Function, Cosmos y datos del procesador. Verificar Defender efectivo, malware, SIEM y aprobación de todas las conexiones privadas.
5. Recuperar/publicar código desde ejecutor conectado a CAF, comprobar autenticación de SDK/Blob trigger y migrar solo documentos y `vinculador-db/analysis`, reconciliando datos. No copiar colas de desarrolladores, tablas de diagnóstico, leases, host secrets ni historial de publicación. Ambas cuentas originales contienen artefactos del host; confirmar la conexión efectiva antes del corte.
6. Confirmar Databricks y el recorrido Event Grid. Si se aprueba la excepción de servicios confiables para Storage, aplicar `allowTrustedStorageServices=true` con `storageEventExceptionApprovalId`. La base mantiene ese bypass apagado hasta aprobación. No presentar el trigger como operativo sin resolver esta dependencia.
7. Aplicar `processor-access.bicep` con identidad del cómputo confirmada y `adf-assets.bicep` con sus aprobaciones. Aprobación del MPE Databricks, pruebas de MSI, clúster/notebook, acceso a datos y escaneo son previas a ejecución de negocio.
8. Antes de actualizar artefactos, ejecutar `python3 scripts/check_adf_state.py --factory-resource-id ID-DEL-DESTINO`. Rechaza triggers activos o estado desconocido. Si existe un trigger activo, detenerlo por operación autorizada y comprobarlo antes del despliegue. Omitir `runtimeState` en Bicep no lo detiene. Un trigger nuevo se entrega sin arrancar y se debe verificar su estado después de crearlo.
9. Confirmar modelos, cuotas y evidencias `*Verified`, incluida orquestación, antes de activar Function. En ventana controlada probar carga/escaneo/OCR/Batch/Cosmos/notebook/notificaciones y recepción SIEM. Activar el trigger ADF mediante una operación explícita posterior; probar ausencia de ejecuciones duplicadas y cambiar consumidores solo al aceptar resultados.

Incremental no es rollback: quitar un modelo, rol o trigger del archivo no elimina lo ya desplegado ni detiene procesamiento. Conservar origen y respaldos; ante fallo controlar ejecuciones en curso, detener nueva carga y retornar consumidores. La plantilla no contiene una orden de despliegue, activación de triggers, push o eliminación.

## Referencias técnicas

- [IR y managed private endpoints ADF](https://learn.microsoft.com/en-us/azure/data-factory/managed-virtual-network-private-endpoint): red Microsoft separada y aprobación de conexiones.
- [Databricks linked service y MSI](https://learn.microsoft.com/en-us/azure/data-factory/compute-linked-services): configuración del conector, distinta de los permisos del notebook sobre datos.
- [Blob trigger con identidad](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-trigger): requisitos de conexión y permisos Blob/Queue.
- [Trigger de eventos ADF](https://learn.microsoft.com/es-es/azure/data-factory/how-to-create-event-trigger): integración Event Grid, filtros y restricciones de red.

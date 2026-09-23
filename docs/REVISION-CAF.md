# Revisión CAF de ANALISISDEC

## Base y alcance

Origen: `main-6.bicep`, RG `RG-POC-ANALISISDEC-CR`, East US. El [inventario saneado](../references/inventario.json) registra SHA-256, tipos de recurso, modelos históricos y 15 Functions. No se versiona el export completo: contiene metadatos operativos y centenares de recursos administrados por Azure que no constituyen una especificación de despliegue.

Referencias del usuario: `CAF_Plan_Hub_IA_Spokes.pdf` y `DDA_Azure_AI_Landing_Zone_CAF.pdf`, particularmente topología de hub/spokes, Zero Trust, servicios corporativos y gobierno APIM. Se aplican como guía de arquitectura; sus instrucciones internas no amplían el encargo. Se aplican también `docs/guia-agentes-bicep.md` del repositorio de landing zone y los acuerdos de seguridad de ESG/ECOCAF. Esta rama usa la estructura actual por spoke, con entrada `infra/main.bicep`.

Los documentos difieren en ciertos límites de suscripción y organización de APIM. Este cambio no decide esa distribución por plataforma: exige un RG nuevo, consume IDs corporativos y deja a plataforma el contrato APIM (`ws-ai`/`gw-ai`, Products, rutas y propiedad). Se conservan las dos cuentas de IA que aparecen en ANALISISDEC hasta confirmar si se consumirán cuentas compartidas. No se añade Foundry Agent Service: el inventario muestra una aplicación Functions que llama OpenAI y Document Intelligence.

## Recursos y decisiones

| Recurso | Configuración nueva | Decisión respecto al origen |
| --- | --- | --- |
| Function y plan | Linux Python 3.13, Functions ~4, B1, una instancia, Always On; detenida por defecto | Conserva capacidad del inventario; añade identidad, Entra obligatorio, TLS 1.2, endpoint privado y elimina publicación básica |
| Storage del host | StorageV2 Standard_LRS; Blob, Queue y Table privados; identidad sin claves compartidas | Cuenta nueva exclusiva para Functions/Durable; no copiar artefactos de ejecución |
| Storage de documentos | StorageV2 Standard_LRS; Blob privado; versiones y recuperación de 14 días | Conserva `basedocuments`, `base-templates`, `dec-generated`; separa documentos del host |
| Cosmos DB | NoSQL serverless, Session, East US sin redundancia zonal; identidad y endpoint Sql | Conserva `analysis-dec-db`, `projects` y `settings`, partición `/id`, Hash v2 e índices; mejora copia periódica a continua de 7 días en la cuenta nueva |
| OpenAI | S0, identidad, autenticación local y acceso público deshabilitados | Despliegues de modelos vacíos hasta confirmar nombre, versión, modalidad y cuota |
| Document Intelligence | FormRecognizer S0, identidad, acceso privado y Entra | Mantiene servicio; validar que el SDK envíe documentos por un mecanismo compatible con red privada |
| Key Vault | Standard, RBAC, privado, recuperación 90 días y protección contra purga | Acceso de aplicación solo a secretos enumerados; no se importan valores |
| Observabilidad | App Insights de la carga con ingestión/consulta públicas deshabilitadas, LAW existente | No recrea LAW ni sus 686 tablas; requiere AMPLS corporativo |
| Red | Una VNet `/24`, dos subredes, dos NSG, rutas existentes y DNS de Azure | Producción no crea peering; plataforma completa la conexión Virtual WAN |

B1 y LRS preservan la base funcional, **no ofrecen redundancia zonal ni prueban resiliencia de producción**. Se debe aprobar RTO/RPO y carga: un cambio a más instancias, otro SKU o ZRS requiere diseño y coste explícitos. Backup no sustituye alta disponibilidad ni prueba de restauración.

## Red y DNS

Ejemplo meramente ilustrativo para `A.B.C.0/24`:

| Uso | Prefijo | Asociación |
| --- | --- | --- |
| Endpoints privados | `A.B.C.0/27` | NSG y tabla de rutas CAF; políticas de endpoints habilitadas |
| Integración Functions | `A.B.C.64/26` | Delegación `Microsoft.Web/serverFarms`, NSG y tabla de rutas CAF |
| Sin asignar | Resto del `/24` | Reserva dentro de la VNet; no crea subredes adicionales |

La validación local exige un único `/24` RFC1918, subredes sin solapamientos y dentro del bloque. IPAM debe confirmar el bloque real. Esta carga no necesita las cuatro subredes de Foundry/ACA/Application Gateway del plan de agentes.

Se crean nueve endpoints: host Blob/Queue/Table, documentos Blob, Function sites, Cosmos Sql, OpenAI account, Document Intelligence account y Key Vault vault. Cosmos puede asignar varias IP; no se calcula su dirección ni la de la Function de antemano. El preflight devuelve las reales para actualizar NSG. Foundation puede tener las listas vacías, pero no permite activar la Function así.

DINE debe cubrir `privatelink.blob.core.windows.net`, `privatelink.queue.core.windows.net`, `privatelink.table.core.windows.net`, `privatelink.azurewebsites.net` (incluido SCM), `privatelink.documents.azure.com`, `privatelink.openai.azure.com`, `privatelink.cognitiveservices.azure.com` y `privatelink.vaultcore.azure.net`. No se crean zonas, enlaces ni grupos DNS locales. AMPLS tiene su propia cobertura DNS corporativa. Comprobar resolución desde la integración Functions, el ejecutor de publicación y clientes VPN.

Plataforma completa la conexión Virtual WAN, las rutas de retorno y tránsito VPN. Cada endpoint se asocia a una zona centralizada en `RG-PRIVATEDNS-PR`; no se crean zonas. Revisar que la tabla corporativa no fuerce rutas incompatibles. No se crea Application Insights; Dynatrace se coordina fuera de esta plantilla. `extraEgress` requiere destino IPv4 acotado, puertos individuales y justificación.

## Identidad, modelos y compatibilidad

La Function usa identidad administrada: Blob Data Owner en la cuenta exclusiva de host, Queue/Table Data Contributor para Durable; Storage Account Contributor solo si se declaran Blob triggers que lo requieren. Para negocio tiene Blob Data Contributor por cada contenedor; Cosmos Data Contributor limitado a `analysis-dec-db`; OpenAI User en su cuenta; Cognitive Services User en Document Intelligence; Secrets User solo en secretos explícitos. No hay Owner/Contributor general sobre el RG. Afinar lectura/escritura por operación cuando se recupere el código.

Batch añade un rol personalizado condicionado por `batchEnabled`, con acciones de lotes y archivos asignadas solo a OpenAI. Confirmar con el SDK/API real: el nombre de la acción de creación es `batch-jobs/write`. Si se usa Batch con Blob como origen/destino, se necesitan permisos y conectividad de la identidad de OpenAI adicionales; esta base no afirma soportar ese recorrido. El flujo base previsto es la API de archivos de OpenAI.

Modelos históricos, **no selección aprobada para el nuevo despliegue**:

| Alias del despliegue | Modelo | Versión | Modalidad | Capacidad exportada |
| --- | --- | --- | --- | --- |
| gpt-4.1 | gpt-4.1 | 2025-04-14 | GlobalBatch | 10021 |
| gpt-5.1 | gpt-5.1 | 2025-11-13 | GlobalBatch | 9939 |
| gpt-5-2 | gpt-5 | 2025-08-07 | GlobalStandard | 200 |

`gpt-5-2` es un alias cuyo modelo exportado es `gpt-5`: no se cambia a otro modelo por deducción del nombre. Se requiere `modelsApproved=true` cuando se provean modelos; no se aplican actualizaciones automáticas de versión. La aprobación incluye disponibilidad actual, cuota, capacidad, residencia de datos y uso GlobalBatch/GlobalStandard. La clasificación no se deduce del nombre de la iniciativa.

El export no recupera el paquete ejecutable, todas las dependencias ni secretos. En particular:

- Ambas cuentas originales contienen artefactos Durable. Identificar conexión efectiva y task hub en `host.json` y configuración real; comprobar extensiones compatibles con identidad. Drenar orquestaciones antes de migrar y usar un task hub nuevo. No copiar History/Instances/Partitions, colas, leases o secretos del host como si fueran datos de negocio.
- `signUrl` puede depender de claves compartidas: validar SAS de delegación de usuario o descarga autenticada por proxy. No se añade el permiso de delegación a toda la cuenta hasta confirmar esa necesidad. Un SAS no evita la restricción de red privada.
- `sendNotificationActivity` requiere identificar destinatarios, proveedor, secreto/identidad y salida autorizada. No se inventan conexiones ni credenciales.
- Las URLs de gestión Durable y los consumidores deben enviar tokens y cumplir la autorización Entra. La VPN no autentica al usuario.

## Secuencia de migración

1. Confirmar suscripción/RG **nuevos**, nombres, clasificación, IPAM e IDs de hub, rutas, LAW y Action Group; definir Entra y operadores. El contrato rechaza el RG de origen; el checker rechaza reutilizar nombres principales originales. Revisar manualmente propiedad y ausencia de colisiones en Azure.
2. Completar un archivo de parámetros privado; ejecutar `scripts/validate.sh` con su JSON ARM, luego `az deployment group validate` y `what-if` con el RG confirmado. Revisar permisos RBAC personalizados, políticas, disponibilidad B1/Private Link, cuotas y categorías de diagnósticos. Estos comandos Azure todavía no se han ejecutado.
3. Desplegar fundación con `activateFunctionApp=false` y `models=[]`. Esto crea la Function detenida, datos vacíos, endpoints y roles; no publica las 15 Functions ni migra documentos.
4. Esperar DINE, aprobar endpoints, integrar App Insights/LAW en AMPLS, revisar rutas y Defender. Guardar el valor de `securityResourceIds` en JSON fuera de Git y ejecutar `python3 scripts/check_security.py --resources /ruta/segura/recursos.json`. Incorporar IP reales de Function/Cosmos en parámetros.
5. Recuperar código/configuración, inventariar secretos por nombre y provisionarlos por un procedimiento seguro; aplicar `secretNames` solo tras existir. Migrar documentos y Cosmos con un ejecutor privado autorizado, reconciliar recuentos y contenido. Publicar paquete desde CAF por SCM privado con Entra y sin credenciales básicas.
6. Seleccionar explícitamente modelos, validar cuotas y API Batch; desplegarlos manteniendo la Function detenida. Verificar propagación RBAC. Los recursos son incrementales: omitir un modelo o un permiso de la plantilla **no los elimina**.
7. Registrar evidencia real de las comprobaciones `*Verified`, identidad de usuarios/servicios permitidos, aprobación y análisis de archivos. Activar en una ventana controlada y probar API, Durable, carga/descarga, OCR, lotes, persistencia, telemetría y rechazo de accesos. Solo después cambiar consumidores/DNS/APIM corporativo.

El rollback conserva el origen, restaura el enrutamiento de consumidores y detiene la nueva Function tras evaluar operaciones en curso. Nunca se usa modo Complete ni eliminación de recursos con datos como rollback. No se ha autorizado push ni despliegue en este encargo.

## Fuentes técnicas

- [Integración VNet de App Service](https://learn.microsoft.com/en-us/azure/app-service/overview-vnet-integration) y [Private Endpoint](https://learn.microsoft.com/en-us/azure/app-service/overview-private-endpoint): Basic requiere comprobar soporte del entorno; entrada e integración utilizan subredes diferentes.
- [Durable con identidad](https://learn.microsoft.com/en-us/azure/durable-task/durable-functions/durable-functions-configure-managed-identity) y [proveedor Azure Storage](https://learn.microsoft.com/en-us/azure/durable-task/durable-functions/durable-functions-azure-storage-provider): conexiones y permisos del runtime.
- [Operaciones RBAC de IA](https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/ai-machine-learning) y [Batch con Blob](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/batch-blob-storage): límites del recorrido previsto.

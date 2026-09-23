# Seguridad de Vinculador

## Controles y responsables

| Control | Plantilla del spoke | Evidencia pendiente |
| --- | --- | --- |
| Clasificación | Etiqueta `DataClassification` requerida | Dueño de datos aprueba sensibilidad, residencia, retención y uso GlobalBatch |
| Red | Endpoints privados, NSG por subred, salida por rutas corporativas | CAF verifica DNS/DINE, rutas de retorno VPN, firewall y resolución AMPLS |
| Identidad | Entra en Function, lista de object IDs, identidades administradas para datos | Validar autorización por operación, permisos y consumidores; la VPN no autentica |
| Cifrado | HTTPS/TLS mínimo 1.2; cifrado administrado por Azure en reposo | CMK según riesgo; no se introducen por defecto ni se reclama doble cifrado |
| Auditoría | Logs de Function, Blob/Queue/Table, Cosmos, IA y ADF a LAW central; Event Hub opcional | SOC verifica recepción, retención y detecciones; Activity Log y exportación de alertas Defender corresponden a plataforma |
| Observabilidad | App Insights privado y alertas de 5xx/volumen a Action Group existente | AMPLS, fallos de pipeline, errores Blob/colas poison, tiempos Batch y restauración necesitan pruebas |
| Archivos | Defender Storage y activación condicionada a `fileScanningVerified` | El código debe impedir procesar archivos pendientes, maliciosos o sin resultado válido |
| Recuperación | Blob 14 días y versiones; Cosmos continuo 7 días | RTO/RPO, restauración y respaldo antes de migración; P1v4 de una instancia y LRS no equivalen a HA zonal |
| Gobierno de IA | Modelos explícitos y aprobación | Purview, SharePoint y guardrails permanecen en el hub por acuerdo; su cumplimiento no está probado por este Bicep |

## NSG y permisos

Los NSG son filtros: permiten solo los orígenes, destinos y puertos definidos y deniegan el resto. Los clientes llegan a la IP privada de la Function por 443, mientras que los datos quedan disponibles solo para la integración de aplicación y el cómputo autorizado. Cosmos Direct utiliza TCP 0–65535 exclusivamente hacia IP privadas de Cosmos. `processorDataPrivateIps` debe contener las IP reales de Blob/Queue de negocio, Cosmos e IA, y excluir host/Function. El preflight obtiene esa lista de endpoints aprobados; no se deben introducir rangos generales para evitar esta comprobación.

La Function recibe Blob Data Owner sobre el host, Queue Data Contributor y Storage Account Contributor cuando se utiliza el Blob trigger (valor predeterminado de esta carga). El permiso de control del host se limita a la cuenta exclusiva; no hay Contributor sobre el RG. Durable está deshabilitado por defecto porque no aparece en el inventario. Table Data Contributor solo se asigna si se confirma su necesidad mediante `hostUsesTables`.

En datos de negocio, la Function recibe Blob Data Owner en el contenedor del trigger, Blob Data Contributor en los otros tres y Queue Data Contributor en la cuenta de documentos para colas del trigger. Cosmos Data Contributor se limita a `vinculador-db`; OpenAI User y Cognitive Services User se limitan a sus cuentas. Batch añade un rol personalizado de operaciones de archivos/lotes, sin permisos de administración del recurso. Revisar los privilegios con pruebas negativas y reducir escritura según se recupere el código.

La identidad del procesador se configura en una etapa separada: acceso Blob por contenedor, Cosmos por base e IA por cuenta, sin permisos del host ni colas del trigger. Esto no configura una credencial de datos dentro de Databricks: su propietario debe instalar el mecanismo de identidad/Unity Catalog compatible y confirmar que la identidad suministrada es la utilizada por el notebook.

## Defender y archivos

Ambos Storage declaran Defender habilitado con `overrideSubscriptionLevelSettings=false`. La plantilla hereda CAF; no cambia planes de suscripción ni límites de análisis. El script de lectura comprueba `AppServices`, `CosmosDbs`, `AI`, `CloudPosture` Standard, Defender en ambas cuentas y análisis al cargar en documentos por defecto. Una lectura fallida bloquea el preflight.

No se añaden Defender for Key Vault o Containers, porque esta carga no despliega esos recursos. Los planes y cobertura del Databricks externo se verifican con su propietario. Un plan AI activo no prueba cobertura de todas las APIs/modelos/Batch ni de Document Intelligence. Revisar alcance efectivo, exclusiones y limitaciones con Seguridad.

Defender no detiene automáticamente la Function Blob trigger. Antes de activar, el código debe esperar un resultado válido para la versión concreta del archivo, rechazar errores/no analizados y bloquear documentos detectados. También deben esperar el resultado el notebook y cualquier productor del JSON que arranca ADF. No basta escribir `fileScanningVerified=true`, ni confiar en etiquetas de blob modificables por la misma identidad que carga datos. Quedan pendientes pruebas controladas de detección, tiempos de espera, bloqueo y notificación SOC.

`configurationChecked=true` solo acredita las consultas del script: no certifica alertas recibidas, límites mensuales suficientes, análisis sin exclusiones o bloqueo de procesamiento. Las aprobaciones e indicadores de Bicep deben corresponder a evidencia externa real.

## Excepción del recorrido Storage/Event Grid

Los eventos ADF usan un system topic administrado y su integración de servicio. No se copia el webhook del export ni se crea un endpoint público de aplicación para resolverlo. Tampoco se afirma que un system topic admita Private Endpoint: la configuración del canal de eventos debe aprobarse por plataforma.

`allowTrustedStorageServices=false` mantiene bypass deshabilitado. Si Seguridad aprueba el mecanismo de servicios confiables exigido por ese recorrido, puede habilitarse con un identificador de aprobación en la cuenta de documentos, manteniendo acceso público deshabilitado. Esa excepción es más amplia que una regla NSG y debe quedar justificada. El parámetro no demuestra que el trigger funcione: probar publicación, suscripción y entrega reales. `storageEventsApproved` de la etapa ADF exige que este diseño se haya validado; no abrir la red automáticamente para pasar las pruebas.

## Aceptación operativa

Probar: rechazo sin token y con identidad no permitida; rechazo público; acceso privado por VPN; SCM desde ejecutor corporativo; Blob trigger con identidad; aislamiento entre host y datos; notificaciones; carga/escaneo/OCR; Batch; persistencia Cosmos; notebook con la identidad correcta; trigger JSON sin duplicados; auditoría SIEM; alertas; restauración; retorno controlado al origen.

No se ha ejecutado esta aceptación ni `validate`/`what-if` de destino. Las lecturas realizadas verifican inventario del origen, no cumplimiento de la futura instalación.

## Fuentes

- [Defender Storage y configuración avanzada](https://learn.microsoft.com/en-us/azure/defender-for-cloud/advanced-configurations-for-malware-scanning).
- [Análisis de malware al cargar](https://learn.microsoft.com/en-us/azure/defender-for-cloud/on-upload-malware-scanning).
- [Cobertura de Defender para IA](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-threat-protection).
- [Eventos de almacenamiento en ADF](https://learn.microsoft.com/es-es/azure/data-factory/how-to-create-event-trigger).

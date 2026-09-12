# Seguridad de ANALISISDEC

## Controles del spoke y responsabilidades CAF

| Control | Implementado en Bicep | Validación pendiente / responsable |
| --- | --- | --- |
| Clasificación | Etiqueta `DataClassification` obligatoria mediante contrato | Dueño de datos y Seguridad determinan sensibilidad, residencia y retención |
| Red | NSG por subred, endpoints privados y acceso público deshabilitado | Plataforma: rutas, DNS/DINE, VPN, firewall, peering inverso |
| Identidad | Entra obligatorio, respuesta 401 sin autenticación, lista de object IDs; identidad administrada para datos | Aplicación: autorización por operación; Identidad: registro, roles, PIM y ciclo de vida |
| Cifrado | HTTPS/TLS 1.2; cifrado administrado por Azure en reposo; Storage sin claves compartidas | Clasificación determina si se necesitan CMK u otros controles; no se configura CMK por defecto |
| Auditoría | Diagnósticos de Function, Storage Blob/Queue/Table, Cosmos, OpenAI, Document Intelligence y Key Vault hacia LAW central; Event Hub opcional | SOC confirma recepción, retención, correlación y acceso; plataforma enruta Activity Log y alertas Defender al SIEM |
| Telemetría | App Insights privado; alertas Function de 5xx y volumen con Action Group existente | AMPLS/DNS y pruebas de llegada, fallos de dependencias, latencia y operación Durable |
| Archivos | Defender Storage habilitado; activación condicionada a comprobación de análisis | Código debe bloquear pendientes, maliciosos, errores/no analizados y resultados obsoletos; SOC valida el recorrido |
| Resiliencia | Recuperación de blobs 14 días, versiones, Cosmos continuo 7 días, Key Vault 90 días/purge protection | Aprobar RTO/RPO y realizar restauración; B1 de una instancia y LRS no son HA zonal |
| Purview, SharePoint y guardrails | Fuera del spoke por acuerdo del usuario | Hub; no se declara cobertura por solo referenciarlo |

Los NSG son filtros de tráfico de las subredes. Aquí permiten a clientes VPN/APIM llegar únicamente al endpoint de la Function por 443; los clientes no reciben acceso directo a los datos. La integración Functions puede llegar a endpoints por 443, a DNS y a Entra/Monitor. Cosmos Direct abre TCP 0–65535 únicamente desde la integración a las IP privadas confirmadas de Cosmos, porque ese protocolo necesita puertos dinámicos. El resto queda denegado. Las IP de operadores habilitan administración privada por 443 y deben limitarse a ejecutores/bastiones corporativos ya existentes. Los NSG no sustituyen autenticación, autorización o inspección del firewall.

## Defender

Las dos cuentas Storage reciben `Microsoft.Security/defenderForStorageSettings`, `isEnabled=true`, `overrideSubscriptionLevelSettings=false`. Se conserva la configuración de suscripción administrada por CAF; esta plantilla no modifica planes de suscripción ni inventa un límite de análisis mensual. La herencia y su efectividad deben comprobarse después del despliegue.

El preflight de solo lectura comprueba planes `AppServices`, `KeyVaults`, `CosmosDbs`, `AI` y `CloudPosture` en Standard, Defender en ambas cuentas Storage y análisis al cargar en la cuenta de documentos por defecto. Si no puede leerlos, falla. La compra/activación de planes y su alcance de suscripción corresponde a plataforma y Seguridad; que el código los compruebe no significa que estén activados.

No hay ACR, AKS ni Container Apps en este inventario: no se añade Defender for Containers sin un recurso que lo requiera. `AI` Standard tampoco demuestra protección de cualquier API/modelo ni de Document Intelligence. Verificar soporte de los modelos elegidos y de Batch con Seguridad; no equiparar Defender con guardrails de aplicación. [Cobertura de Defender para IA](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-threat-protection).

`configurationChecked=true` solo confirma las lecturas que realiza el script. No certifica ausencia de exclusiones o anulaciones de planes a otro alcance, datos detectados, retención SIEM ni respuesta a incidentes. Revisar cobertura efectiva por recurso en Defender for Cloud, exclusiones de análisis, tamaño/tipo de documento, límites mensuales y costes. [Herencia y configuración de Defender Storage](https://learn.microsoft.com/en-us/azure/defender-for-cloud/advanced-configurations-for-malware-scanning).

El análisis no es un bloqueo automático. Un documento puede estar pendiente o quedar sin analizar; la aplicación debe esperar un resultado válido para esa versión antes de enviarlo a OCR/OpenAI, y manejar fallos con cierre de acceso. No confiar únicamente en una etiqueta de blob que la propia identidad escritora puede modificar. Definir el recorrido corporativo de eventos/resultados y probar un archivo de prueba controlado. `fileScanningVerified=true` se declara después de esa evidencia; no activa un mecanismo de cuarentena. [Análisis al cargar](https://learn.microsoft.com/en-us/azure/defender-for-cloud/on-upload-malware-scanning).

## Aceptación

Registrar evidencia, responsable y fecha para: DNS y SCM privados; 401 sin token; rechazo con identidad no permitida; rechazo público; acceso a documentos solo mediante el flujo aprobado; ejecución Durable y reinicio; permisos positivos y negativos; carga y bloqueo de archivos; modelos y Batch; OCR; notificaciones; auditoría en el SIEM; alerta al Action Group; restauración de datos y retorno a la aplicación original.

Los indicadores `inventoryVerified`, `networkVerified`, `defenderVerified`, `siemVerified`, `applicationVerified` y `securityApprovalId` son condiciones de despliegue, no resultados de pruebas automáticas. El Bicep no demuestra por sí solo la aprobación corporativa.

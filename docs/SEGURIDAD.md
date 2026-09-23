# Seguridad de MOP Express

## Controles por responsabilidad

| Control | Definido en Bicep | Pendiente de aceptación |
| --- | --- | --- |
| Clasificación | Etiqueta `DataClassification` obligatoria | Dueño de datos y Seguridad definen sensibilidad, residencia y retención |
| Red | VNet `/24`, NSG, endpoints y acceso público deshabilitado | CAF verifica VPN, DNS/DINE, rutas, firewall y AMPLS |
| Identidad | Entra obligatorio y lista de object IDs; identidad administrada para datos | Roles de aplicación, PIM, ciclo de vida y pruebas positivas/negativas |
| Cifrado | HTTPS/TLS 1.2 y cifrado de servicio administrado por Azure en reposo | CMK si lo exige el riesgo; no se presupone ni configura por defecto |
| Auditoría | Logs de Function, Blob/Queue/Table, Cosmos y cuentas IA hacia LAW existente; Event Hub opcional | SOC valida recepción, retención, consultas y alertas; Activity Log y exportación de Defender corresponden a plataforma |
| Telemetría | App Insights privado y alertas de 5xx/volumen hacia Action Group existente | Probar AMPLS y añadir umbrales operativos de Durable/Batch conforme a la carga real |
| Archivos | Defender Storage, versiones/recuperación, activación condicionada a escaneo | Código debe impedir procesamiento mientras no exista un resultado válido |
| Recuperación | Documentos RA-GRS; blobs recuperables 14 días; Cosmos continuo 7 días | RTO/RPO, restauración, conmutación, consistencia y regreso al origen |
| Gobierno de IA | Modelos/versiones explícitos y aprobación de modalidad | Purview, SharePoint y guardrails del hub quedan fuera por acuerdo; no se afirma cobertura verificada |

Los NSG filtran tráfico entre redes: los clientes VPN solo alcanzan Function por 443; la integración de Functions llega a sus servicios privados. Cosmos Direct admite TCP 0–65535 únicamente hacia las IP verificadas de Cosmos, no hacia toda la subred. Se deniega el resto salvo excepciones de salida explícitas. Los NSG no sustituyen el token Entra, la autorización de operaciones o el firewall corporativo.

## Mínimo privilegio

Durable utiliza Blob Data Owner, Queue Data Contributor y Table Data Contributor en la cuenta exclusiva del host. No se concede Storage Account Contributor salvo que se incorporen Blob triggers y se declare su necesidad. Las cuentas de negocio quedan separadas del estado del runtime.

La aplicación recibe permisos Blob por los contenedores `documents` y `base-templates`; Cosmos por `premop-db`; OpenAI y Document Intelligence por sus cuentas. El rol Batch tiene solo acciones concretas de archivos/lotes, condicionado por `batchEnabled`, y su asignación se limita a OpenAI. No hay Owner/Contributor sobre RG o suscripción. Afinar escritura/lectura por operación tras recuperar código.

Los usuarios permitidos son object IDs de usuarios/servicios, no IDs de grupos o client IDs intercambiables. La autorización funcional de la aplicación y el acceso a los enlaces generados requieren pruebas: no basta estar conectado por VPN.

## Defender

Ambas cuentas Storage declaran `isEnabled=true` y `overrideSubscriptionLevelSettings=false`. La plantilla hereda la configuración CAF y no cambia planes de suscripción, cuotas de análisis ni exclusiones. El script `check_security.py` consulta `AppServices`, `CosmosDbs`, `AI` y `CloudPosture` en Standard, Defender en ambos Storage y análisis al cargar en documentos por defecto; falla cuando las lecturas no pueden completarse.

Seguridad/plataforma deben habilitar o corregir planes ausentes y confirmar cobertura efectiva por recurso. No se añaden Defender for Containers ni Key Vault porque esos recursos no forman parte del spoke. AI Standard no prueba cobertura de todo modelo, API, Batch o Document Intelligence; verificar compatibilidad concreta y no confundir Defender con guardrails de aplicación.

`configurationChecked=true` solo describe las consultas del script. Revisar herencia, exclusiones, límites mensuales, tamaños/tipos soportados, fallos de análisis y llegada al SIEM. Las alertas Defender y los logs del recurso son recorridos distintos; ambos requieren integración corporativa.

El análisis de malware no bloquea por sí mismo una actividad Durable. La aplicación debe esperar resultado válido para la versión del documento antes de OCR/IA, y bloquear maliciosos, pendientes, errores o no analizados. No confiar únicamente en tags modificables por la misma identidad que carga el blob. `fileScanningVerified=true` solo se registra después de probar este recorrido y la respuesta SOC; no configura cuarentena automáticamente.

## Aceptación operativa

Comprobar autenticación y rechazo a usuarios no autorizados, rechazo público, DNS/SCM privados, permisos de datos mínimos, carga y bloqueo de archivos, extracción OCR, Batch, `signUrl`/descarga, notificaciones, recuperación de proyectos, reinicio/reanudación Durable, auditoría SIEM, alertas, restauración y rollback sin ejecutar dos veces el mismo trabajo.

B2 de una instancia no proporciona redundancia zonal. RA-GRS replica de forma asíncrona y conserva lectura secundaria, pero esta plantilla no implementa el acceso privado al secundario o failover de toda la aplicación. Cosmos de una región y el host LRS requieren su estrategia propia. Mantener los recursos originales hasta aceptar recuperación y corte.

El endpoint de Azure OpenAI se registra en `privatelink.openai.azure.com`; Document Intelligence utiliza `privatelink.cognitiveservices.azure.com`. Ambos IDs se reciben desde las zonas centrales y no se crean zonas locales.

No se han realizado estas pruebas ni `validate`/`what-if` del nuevo destino. Las lecturas Azure realizadas solo corroboran parte del inventario de origen.

## Referencias

- [Defender Storage: configuración e herencia](https://learn.microsoft.com/en-us/azure/defender-for-cloud/advanced-configurations-for-malware-scanning).
- [Análisis al cargar](https://learn.microsoft.com/en-us/azure/defender-for-cloud/on-upload-malware-scanning).
- [Protección de amenazas de IA](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-threat-protection).

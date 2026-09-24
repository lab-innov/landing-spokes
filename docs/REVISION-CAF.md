# Revisión CAF de Smart Review

## Alcance recuperado

El export `main-8.bicep` es un inventario parcial del RG original y no una plantilla reutilizable: supera el límite de recursos, contiene APIs preliminares y exporta hijos internos administrados por Azure. El mensaje `ExportTemplateCompletedWithErrors` confirma omisiones de elementos internos de Functions, Cosmos DB, Storage, Azure Monitor y Cognitive Services. Estos hijos no se recrean; la plantilla declara únicamente recursos configurables de la solución.

La guía de despliegue y los dos documentos técnicos muestran una solución distribuida originalmente entre varios RG. Para el spoke nuevo se consolida la infraestructura dedicada de Smart Review; las APIs compartidas de permisos, notificaciones, auditoría y componentes comunes siguen siendo dependencias externas y no se duplican sin contratos reales.

## Recursos definidos

| Componente | Configuración |
| --- | --- |
| Frontend | App Service Linux Node 22, plan P1v4 dedicado, identidad, Entra, endpoint privado e integración VNet |
| Backend | Function App Linux Python 3.13 / Functions 4, Durable, plan P1v4 dedicado, Entra e identidad administrada |
| Storage de host | StorageV2 Standard_LRS para Blob, Queue y Table de Functions/Durable |
| Storage de negocio | StorageV2 Standard_RAGRS; `basedocuments`, `resoluciones`, `documents`, `batchs-gpt-temporal` y `outputs` |
| Cosmos DB | NoSQL serverless, base `contracts-dco-db`, contenedores `contracts` y `settings`, partición `/id` |
| IA | Azure OpenAI y Document Intelligence privados, sin claves locales; modelos vacíos hasta aprobación de cuota y versión |
| Secretos | Key Vault privado con RBAC, soft delete y protección contra purga |
| Observabilidad | Application Insights workspace-based, retención de 90 días, LAW central y envío obligatorio al Event Hub del SIEM |
| Red | VNet `/24`, subred de endpoints y subredes delegadas separadas para frontend/backend; NSG, UDR existente y endpoints privados |

El frontend y el backend usan planes P1v4, no Basic ni P1v3. Storage y Cognitive Services fijan `publicNetworkAccess: Disabled`, `networkAcls.defaultAction: Deny` y `bypass: None` cuando aplica. Las cuentas Storage deshabilitan claves compartidas.

## DNS, hub y monitoreo

La plantilla consume IDs de las zonas centrales y crea el grupo DNS como hijo de cada endpoint privado. No crea las zonas. Plataforma debe confirmar el alcance de suscripción/RG, enlaces y resolución. El DNS forwarding ruleset y la conexión Virtual WAN hub se realizan manualmente, según el acuerdo de revisión, y están excluidos del Bicep.

Application Insights deshabilita ingestión y consulta públicas. Antes de activar el backend se exige confirmar la asociación efectiva al AMPLS corporativo y la resolución privada. La plantilla no crea AMPLS porque es una capacidad central.

## Compatibilidad de aplicación

La documentación funcional todavía muestra Function keys y variables `VITE_*`. El destino seguro exige Entra ID: el código y el pipeline deben reemplazar `x-functions-key` por tokens y compilar el SPA con la URL privada correcta. Los valores `VITE_*` son de compilación y no se corrigen solamente con App Settings.

También se debe confirmar el runtime Python real (las fuentes difieren entre 3.12 y 3.13), el task hub Durable, el mecanismo de URL firmada sin Shared Key, contratos de las APIs compartidas y cualquier salida autorizada. No se versionan secretos.

## Secuencia recomendada

1. Completar nombres, RG nuevo, IPAM, UDR, zonas DNS, LAW, SIEM, AMPLS, registros Entra, identidades y clasificación.
2. Ejecutar validación local, `az deployment group validate` y `what-if` con parámetros reales.
3. Desplegar la fundación con ambas aplicaciones detenidas y sin modelos.
4. Confirmar endpoints/DNS/rutas, Defender, SIEM, AMPLS y obtener las IP privadas reales con `scripts/check_security.py`.
5. Publicar código, migrar datos, crear secretos por canal seguro y aprobar modelos/cuota.
6. Activar en una ventana controlada y probar autenticación, Durable, blobs, Cosmos, OCR, Batch, telemetría y rechazo público.

No se usa modo Complete ni se elimina la prueba de concepto como mecanismo de rollback.

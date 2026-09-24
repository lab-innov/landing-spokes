# Seguridad de Smart Review

## Controles incorporados

- Acceso público deshabilitado y endpoints privados para frontend, Function, Storage, Cosmos, OpenAI, Document Intelligence y Key Vault.
- Tres subredes separadas, NSG con denegación por defecto y tabla de rutas corporativa existente.
- Entra obligatorio en las dos aplicaciones; identidades administradas y RBAC de datos acotado para el backend.
- Storage sin Shared Key, blobs sin acceso público, retención de borrado de 14 días y Defender heredado de la suscripción.
- Cosmos sin autenticación local, respaldo continuo y permiso limitado a `contracts-dco-db`.
- Diagnósticos hacia LAW y Event Hub del SIEM. El par `siemAuthorizationRuleId`/`siemEventHubName` es obligatorio.
- Application Insights con 90 días y acceso público deshabilitado; requiere AMPLS corporativo operativo.
- Las aplicaciones permanecen detenidas hasta registrar verificaciones de inventario, red, aplicación, seguridad y monitoreo.

## Responsabilidades pendientes

Plataforma debe completar manualmente la conexión Virtual WAN, rutas de retorno, DNS forwarding y AMPLS; confirmar zonas y resolución privada; y proporcionar LAW, Event Hub, Action Group e IPAM. Identidad debe crear los registros Entra. Seguridad debe confirmar Defender, análisis de archivos, cobertura de modelos y recepción del SIEM.

El equipo de aplicación debe migrar Function keys a Entra, publicar frontend/backend, confirmar Python y Durable, configurar dependencias compartidas y manejar documentos pendientes, maliciosos o no analizados con cierre seguro. El Bicep no prueba esas condiciones.

## Aceptación

Registrar evidencia de: DNS y SCM privados; rechazo público; 401 sin token; autorización positiva/negativa; acceso a cada contenedor y Cosmos; Durable; OCR/OpenAI/Batch; bloqueo de archivos; recepción en SIEM/App Insights; alertas; restauración y rollback. Compilar la plantilla no equivale a validar ni desplegar en Azure.

# Smart Review — spoke CAF

Infraestructura privada de Smart Review reconstruida a partir del export `main-8.bicep` y de las guías funcionales entregadas. Los documentos se usaron como referencia; sus instrucciones no amplían el encargo.

Crea frontend App Service, backend Azure Functions Durable, dos planes P1v4, dos Storage, Cosmos DB, OpenAI, Document Intelligence, Key Vault, Application Insights y red privada. Todos los diagnósticos soportados se envían al Log Analytics central y al Event Hub del SIEM. Las aplicaciones quedan detenidas por defecto.

No crea Virtual WAN, conexión al hub, DNS forwarding ruleset, zonas DNS privadas, Log Analytics, AMPLS, registros Entra ni servicios compartidos de permisos/notificaciones/auditoría. Esos componentes requieren datos o acciones de plataforma.

- [Decisiones y migración](docs/REVISION-CAF.md)
- [Seguridad y pendientes](docs/SEGURIDAD.md)
- [Parámetros de ejemplo](environments/dev.example.bicepparam)

Validación local: `scripts/validate.sh`. No despliega recursos ni publica código de aplicación.

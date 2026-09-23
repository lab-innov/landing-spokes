# ANALISISDEC — spoke CAF

Infraestructura privada de ANALISISDEC, revisada contra los documentos de landing zone y los acuerdos de seguridad. La exportación `main-6.bicep` se utiliza como inventario parcial. No contiene el código recuperado de la aplicación.

Crea una Function Python con Durable, plan B1, dos Storage separados, Cosmos DB, OpenAI, Document Intelligence, Key Vault y una VNet `/24` con endpoints privados y NSG. Usa zonas DNS centralizadas; la conexión Virtual WAN de producción queda a cargo de plataforma. No crea peering, DNS personalizado, Application Insights ni IP pública.

La Function queda **detenida**, sin modelos por defecto. Se preservan los contenedores de negocio y el esquema de Cosmos. Defender for Storage queda habilitado con herencia corporativa; los demás planes se verifican, no se administran desde este spoke.

- [Decisiones, recursos y migración](docs/REVISION-CAF.md).
- [Seguridad y comprobaciones pendientes](docs/SEGURIDAD.md).
- [Parámetros de ejemplo](environments/dev.example.bicepparam): contienen marcadores deliberadamente no desplegables.

Validación local: `scripts/validate.sh`. Con parámetros ARM reales, fuera de Git: `scripts/validate.sh /ruta/segura/parametros.json`.

Estado de entrega: compilación y linter correctos; 14 pruebas locales correctas. No se han ejecutado `validate`/`what-if` contra Azure, publicado código de aplicación ni desplegado recursos.

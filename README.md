# MOP Express — spoke privado CAF

Infraestructura modular para migrar MOP Express sin modificar `RG-POC-PreMop-CR`. Conserva Function/Durable con plan B2, Storage del host LRS, documentos RA-GRS, Cosmos `premop-db`, OpenAI Batch y Document Intelligence.

Añade VNet `/24`, NSG, endpoints privados con zonas DNS centralizadas, Entra, permisos por recurso, diagnósticos y Defender Storage con herencia CAF. La conexión Virtual WAN de producción queda a cargo de plataforma; no crea peering, DNS personalizado, Application Insights ni IP pública.

La Function queda detenida y los modelos vacíos por defecto. El código de las 15 Functions, los documentos y el estado Durable no se copian desde el export.

- [Recursos, decisiones y migración](docs/REVISION-CAF.md).
- [Seguridad y condiciones de aceptación](docs/SEGURIDAD.md).
- [Ejemplo de parámetros](environments/dev.example.bicepparam): marcadores que deben sustituirse con valores aprobados.

Validación: `scripts/validate.sh`; con JSON ARM real fuera de Git: `scripts/validate.sh /ruta/segura/parametros.json`.

Estado: compilación y linter sin avisos; 15 pruebas locales correctas. Inventario del origen verificado mediante lecturas Azure. No se ha desplegado la nueva infraestructura ni ejecutado `validate`/`what-if` contra el destino.

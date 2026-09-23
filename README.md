# Vinculador — spoke privado CAF

Bicep modular de Vinculador, preparado para migración paralela sin modificar `RG-POC-VINCULADOR-CR`. La exportación tenía omisiones; se recuperó en Azure, mediante lecturas, el esquema Cosmos y el pipeline/trigger de Data Factory.

Crea Function Python 3.13/P1v3, dos Storage, Cosmos NoSQL, OpenAI, Document Intelligence, Data Factory y una VNet `/24` con NSG y endpoints privados. Usa zonas DNS centralizadas; la conexión Virtual WAN de producción queda a cargo de plataforma. No crea peering, DNS personalizado, Application Insights ni IP pública. Databricks es una dependencia explícita pendiente de confirmar; no se crea ni modifica otro workspace.

Entradas: [fundación](infra/main.bicep), [pipeline ADF](infra/adf-assets.bicep) y [permisos del procesador](infra/processor-access.bicep). La Function queda detenida y los modelos vacíos por defecto. Un trigger ADF nuevo se crea detenido; el comprobador rechaza actualizar triggers activos.

Consultar [recursos, decisiones y migración](docs/REVISION-CAF.md) y [seguridad](docs/SEGURIDAD.md). Los ejemplos contienen marcadores deliberadamente no desplegables.

```bash
scripts/validate.sh
# Con parámetros ARM reales fuera de Git:
scripts/validate.sh /ruta/segura/parametros.json
```

No se ha desplegado infraestructura ni publicado código de aplicación. La validación local no sustituye `validate`, `what-if` ni pruebas operativas en Azure.

Validación de entrega: tres entradas y sus ejemplos compilados, linter sin avisos y 18 pruebas locales correctas.

# ECOCAF: spoke privado

Base modular para una **migración paralela a un RG nuevo**. Conserva la Function
Linux Python 3.13, usa plan Dedicated P1v4 de una instancia y mantiene un StorageV2
LRS exclusivo para el host. La Function y el frontend arrancan detenidos.

Incorpora NSG con permisos explícitos, tabla de rutas corporativa existente,
DNS privado centralizado y conexión de red a cargo de plataforma; Entra con identidades autorizadas, Defender Storage,
auditoría Blob/Queue/Table, SIEM opcional y alertas al Action Group corporativo.
El spoke incluye recursos dedicados para la aplicación completa: Storage HNS de
negocio con contenedor `ecocaf`, Cosmos DB serverless, Azure OpenAI, Document
Intelligence y frontend Node 24 sobre B1. Todos quedan privados, sin autenticación
por claves y con identidades administradas/RBAC. Los modelos de OpenAI no se crean
sin aprobación explícita. ADF y Databricks se excluyen: la evidencia revisada los
mezcla con Vinculador/iDataFactory y no demuestra que ECOCAF los use.

Las APIs comunes de auditoría, notificaciones y conversión PDF permanecen compartidas
mediante URLs privadas verificadas; esta plantilla no las duplica. Antes de activar
se exige migrar el código de claves a identidad, migrar datos y confirmar esos
contratos, la red, Defender, SIEM y autenticación Entra.

```bash
./infra/ecocaf-spoke/validate.sh
python3 infra/ecocaf-spoke/check_parameters.py /ruta/privada/parametros.json
```

El ejemplo `main.bicepparam` contiene marcadores y se rechaza deliberadamente.
Preparar valores reales fuera de Git. `applicationSettings` es un objeto seguro
con la configuración completa: no pegar ni versionar sus valores.

Consultar [inventario pendiente](INVENTARIO.md), [revisión CAF](REVISION-CAF.md)
y [seguridad/despliegue](SEGURIDAD.md). Compilar no publica código ni prueba las
23 rutas HTTP de ECOCAF.

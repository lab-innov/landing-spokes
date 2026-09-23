# ECOCAF: spoke privado

Base modular para una **migración paralela a un RG nuevo**. Conserva la evidencia
exportada: Function Linux Python 3.13, plan Dedicated P1v4 de una instancia y
StorageV2 LRS de host. La Function arranca detenida.

Incorpora NSG con permisos explícitos, tabla de rutas corporativa existente,
DNS privado centralizado y conexión de red a cargo de plataforma; Entra con identidades autorizadas, Defender Storage,
auditoría Blob/Queue/Table, SIEM opcional y alertas al Action Group corporativo.
La documentación funcional confirma Blob de negocio, Cosmos DB, Azure OpenAI,
Document Intelligence y frontend, pero aún faltan sus contratos desplegables. No se
crean hasta confirmar nombres, datos, modelos, identidad, red y migración. ADF y
Databricks permanecen pendientes porque la guía mezcla recursos de otras soluciones.

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

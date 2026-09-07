# Entrega mediante Databricks Asset Bundle

El repositorio de aplicación debe proporcionar un Asset Bundle que:

1. Use `databricksWorkspaceUrl` de infraestructura.
2. Publique estos notebooks o entregue rutas equivalentes a ADF:
   `/Repos/iData/Caf-ifis-model/(Clone) OpenAI_IFISCAF`,
   `/Repos/iData/Caf-ifis-model/UpdateOnFail` y
   `/IData/DataSintetica/Generacion_Data_Sintetica`.
3. Cree un clúster interactivo con runtime, nodos, bibliotecas y política
   aprobados. Sus nodos no deben tener IP pública.
4. Registre la identidad de Data Factory en el workspace y conceda permisos
   para adjuntarse al clúster y reiniciarlo. ARM Contributor no sustituye
   los permisos de datos de Databricks.
5. Configure credenciales y ubicaciones de Unity Catalog mediante el access
   connector. El contenedor compartido datasintetica tiene acceso de lectura;
   revisar el contrato del notebook antes de solicitar escrituras adicionales.
6. Configure una identidad de ejecución para OpenAI, Document Intelligence y
   Cosmos con permisos mínimos, sin copiar secretos del origen.
7. Entregue el ID del clúster como `databricksClusterId`.

Ejecuta ambos pipelines manualmente y prueba la rama de fallo antes de activar
triggers. El código de notebooks y la creación del clúster no se incluyen en Bicep.

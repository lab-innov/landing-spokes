# Entrega de Databricks

Los notebooks no están en este repositorio. El despliegue de infraestructura crea
el workspace privado y su access connector; el repositorio de aplicación debe:

1. Publicar `model_processing` y `scioteca_webscraping` en
   `/Repos/iData/Caf-esg-model/`, usando el workspace de los outputs.
2. Crear o seleccionar un clúster compatible, con VNet injection, sin IP pública,
   runtime/política aprobados y dependencias accesibles por las salidas CAF.
3. Dar a la identidad ADF los entitlements y permisos de adjuntar/reiniciar el
   clúster. Contributor de ARM no sustituye permisos del plano de datos.
4. Configurar acceso a los dos contenedores ESG mediante access connector/Unity
   Catalog y comprobar aislamiento. La identidad de clúster no recibe ese acceso
   automáticamente por crear el conector.
5. Entregar `databricksClusterId` a la etapa `adf-assets.bicep`, probar ambos
   notebooks y pipelines, y acreditar bloqueo de archivos no analizados.

No iniciar triggers antes de las pruebas y la constancia de seguridad. Ver
[activación ESG](../SEGURIDAD.md). DBFS root administrado no está cubierto por
Defender for Storage; no intentar remediarlo modificando su managed RG.

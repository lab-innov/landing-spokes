# Spoke ESG

Esta rama contiene la infraestructura Bicep del spoke para la solución ESG.

## Recursos desplegados

- Red virtual del spoke con subredes dedicadas.
- Peering desde el spoke hacia el hub corporativo.
- Private Endpoints para los servicios compatibles.
- Microsoft Foundry con proyecto y modelos.
- Azure OpenAI.
- Document Intelligence.
- Grounding with Bing Search.
- Azure Databricks.
- Azure Data Factory.
- Azure Function App.
- Dos cuentas de Storage.
- Azure Cosmos DB.
- Application Insights.
- Identidades administradas y asignaciones RBAC.

## Cambios respecto a la infraestructura original

- Se deshabilita el acceso público a los servicios compatibles.
- Se deshabilita la autenticación mediante claves cuando el servicio lo permite.
- Se agregan Private Endpoints y segmentación por subredes.
- El tráfico de salida utiliza la tabla de rutas suministrada por el hub corporativo.
- El DNS privado queda administrado por las políticas DINE y la infraestructura DNS corporativa.
- Databricks utiliza VNet Injection y nodos sin direcciones IP públicas.
- Function App utiliza integración con la VNet y autenticación con Microsoft Entra ID.
- Los servicios utilizan identidades administradas y permisos RBAC.
- Los diagnósticos se envían al Log Analytics Workspace corporativo.
- La antigua API de Bing Search se reemplaza por Grounding with Bing Search.
- Los pipelines y triggers de Data Factory se definen en Bicep, pero los triggers permanecen detenidos hasta completar la migración.

## Elementos no incluidos

- Código fuente de Function App.
- Contenido de los notebooks de Databricks.
- Migración de datos de Storage y Cosmos DB.
- Peering inverso desde el hub.
- Zonas DNS privadas y políticas corporativas.
- Activación automática de los triggers de Data Factory.

## Validación

Antes de desplegar:

```bash
./tests/esg-spoke-contracts.sh
./scripts/deploy-esg-spoke.sh environments/dev.bicepparam validate
./scripts/deploy-esg-spoke.sh environments/dev.bicepparam what-if
El despliegue debe ejecutarse únicamente después de revisar y aprobar el resultado de what-if.
```

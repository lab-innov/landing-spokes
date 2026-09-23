# Spoke ESG

Esta rama contiene la [infraestructura Bicep del spoke ESG](infra/esg-spoke/README.md), preparada para migración paralela sin modificar `RG-POC-ESG-CR`.

Consultar la [revisión CAF y seguridad](infra/esg-spoke/REVISION-CAF.md) para los controles implementados, las responsabilidades corporativas y las decisiones pendientes.

## Recursos definidos

- Red virtual del spoke con subredes dedicadas.
- Conexión al hub de Virtual WAN a cargo de plataforma.
- Private Endpoints para los servicios compatibles.
- Microsoft Foundry con proyecto; modelos sujetos a aprobación explícita.
- Azure OpenAI.
- Document Intelligence.
- Grounding with Bing Search opcional.
- Azure Databricks.
- Azure Data Factory.
- Azure Function App.
- Dos cuentas de Storage.
- Azure Cosmos DB.
- Diagnósticos en Log Analytics e integración de aplicación con Dynatrace fuera del Bicep.
- Identidades administradas y asignaciones RBAC.

## Cambios respecto a la infraestructura original

- Se deshabilita el acceso público a los servicios compatibles.
- Se deshabilita la autenticación mediante claves cuando el servicio lo permite.
- Se agregan Private Endpoints y segmentación por subredes.
- El tráfico de salida utiliza la tabla de rutas suministrada por el hub corporativo.
- Cada Private Endpoint asocia su grupo a una zona DNS privada central existente.
- Databricks utiliza VNet Injection y nodos sin direcciones IP públicas.
- Function App utiliza integración con la VNet y autenticación con Microsoft Entra ID.
- Los servicios utilizan identidades administradas y permisos RBAC.
- Los diagnósticos se envían al Log Analytics Workspace corporativo.
- Se contempla Grounding with Bing Search como alternativa opcional a la antigua API de Bing Search, sujeta a aprobación.
- Los pipelines y triggers de Data Factory se definen en Bicep, pero los triggers permanecen detenidos hasta completar la migración.

## Elementos no incluidos

- Código fuente de Function App.
- Contenido de los notebooks de Databricks.
- Migración de datos de Storage y Cosmos DB.
- Conexión de Virtual WAN, rutas corporativas y pruebas desde VPN.
- Zonas DNS privadas y políticas corporativas.
- Activación automática de los triggers de Data Factory.

## Validación

Antes de desplegar:

```bash
./tests/esg-spoke-contracts.sh
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam validate
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam what-if
```

Preparar parámetros reales fuera de Git a partir del ejemplo de `environments/esg-spoke`. La validación local no despliega recursos ni acredita cumplimiento en Azure. El despliegue debe ejecutarse únicamente después de revisar y aprobar el resultado de `what-if`.

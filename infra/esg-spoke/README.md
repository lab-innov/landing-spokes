# Spoke ESG privado

Infraestructura paralela con VNet propia, Foundry/proyecto, OpenAI separado,
Document Intelligence, Grounding opcional, Databricks Premium, Data Factory,
Function Linux privada con Entra, dos Storage ZRS, Cosmos DB y Application Insights.
Conserva `esg-db`, sus particiones y los dos pipelines/notebooks ESG.

Reutiliza hub, VPN, tabla de rutas, DNS/DINE, Log Analytics, AMPLS y Action Group
corporativos. No crea APIM, firewall, VPN Gateway, DNS privado ni servicios de
contenedores. El bloque `/24` del otro patrón no se aplica a ESG.

La base incorpora NSG por función, Defender Storage con herencia de CAF,
auditoría de Blob/Queue/Table, destino SIEM opcional, roles acotados, autorización
explícita de la Function y controles previos a activación. Databricks conserva
las reglas administradas de su proveedor.

```bash
./tests/esg-spoke-contracts.sh
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam validate
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam what-if
```

Preparar parámetros reales fuera de Git. El ejemplo contiene marcadores y modelos
históricos sin aprobación: compila, pero el preflight impide desplegarlo tal cual.
Ver [revisión y decisiones](REVISION-CAF.md), [despliegue y seguridad](SEGURIDAD.md)
y [entrega Databricks](databricks/README.md).

Origen: adaptación de `Azure/bicep-ptn-aiml-landing-zone`, commit
`bfbcd97f276cba132c30ec4d33f1baa27098af29`; módulos locales conservados. Esta
revisión no convierte esos módulos en AVM certificados.

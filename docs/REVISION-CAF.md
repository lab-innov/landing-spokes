# Alineación de Foundry Agent con los spokes CAF

## Resultado de la revisión

El patrón comparte la base de controles aplicada a MOP, Vinculador, ANALISISDEC, ECOCAF y ESG: red privada, DNS y conectividad corporativos, identidad administrada, permisos acotados, diagnósticos centrales, comprobación de Defender y activación por etapas. No tiene el mismo inventario: Foundry aloja agentes administrados y una aplicación web en ACA, mientras que MOP/Vinculador/ANALISISDEC utilizan Functions.

Durante el traslado se añadieron tres condiciones que los spokes más recientes ya exigían: `tags.DataClassification`, `modelsApproved=true` cuando se proporcionan modelos y `securityApprovalId` para activar runtime, aplicaciones o gateway. Se validan en el checker y mediante contratos ARM incluso si se omite el checker. Los parámetros de ejemplo y pruebas se actualizaron conjuntamente.

No se cambiaron los módulos de recursos ni reglas NSG del commit original `083c167`. Las rutas se reorganizaron a `infra`, `scripts`, `tests`, `environments` y `docs`. Esto no cambia nombres de recursos existentes: siguen dependiendo del mismo RG y `workload`. No se debe reducir una VNet/subred ocupada para forzar el `/24`; si ya existe otra distribución, realizar migración paralela.

## Comparación de controles

| Aspecto | Foundry Agent | Relación con otros spokes |
| --- | --- | --- |
| Hub/VPN/DNS | Conexión Virtual WAN a cargo de plataforma y grupos de endpoint asociados a zonas centrales existentes | Mismo reparto de responsabilidades; el spoke no crea peerings ni zonas DNS |
| VNet | `/25` Foundry, `/26` ACA, `/27` endpoints y `/27` gateway | Usa todo el `/24`; MOP/Vinculador requieren menos subredes y conservan reserva |
| Entrada | Application Gateway WAF_v2 privado, HTTPS, frontend limitado al gateway; backend interno | Functions usa su propio endpoint privado; no se copia esa topología en ACA |
| Identidad | Identidades separadas para aplicaciones, proyecto y gateway; roles de datos y secretos acotados | Misma política de mínimo privilegio, adaptada a persistencia de agentes y certificados |
| Autenticación web | Contrato de autenticación/autorización Entra en las imágenes reales; `applicationAuthVerified` previo a despliegue | Los spokes Functions configuran authsettingsV2; en este patrón la infraestructura no implementa por sí sola el login |
| Defender | Storage heredado; verificación de KeyVaults, CosmosDbs, AI, postura ACA y análisis de imágenes ACR | No equiparar postura ACA con protección runtime AKS; la cobertura se comprueba por servicio |
| Auditoría | Diagnósticos a LAW/Event Hub corporativos; integración de aplicación con Dynatrace fuera del Bicep | Misma separación entre diagnósticos, Activity Logs, alertas Defender y recepción SIEM |
| Cifrado | HTTPS/TLS, cifrado de servicio, Storage sin claves compartidas, Key Vault RBAC | CMK y otros controles avanzados dependen de clasificación y riesgo |
| Recuperación | Storage ZRS, Cosmos zonal con copia continua 7 días, Search 3 réplicas, ACA/gateway zonales | Mayor redundancia declarada que B2/LRS de MOP; no demuestra SLA compuesto ni RTO/RPO |
| Gobierno | Clasificación y aprobaciones explícitas, modelos sin versión automática, etapas inactivas por defecto | Alineado con los controles de los spokes recientes; los flags representan evidencia externa |

## Condiciones que siguen pendientes

- Foundry `/25` está por debajo de la recomendación de producción `/24` documentada en el diseño acordado; gateway `/27` restringe su crecimiento. Las réplicas configuradas no demuestran que la carga quepa. Validar cuotas, IP disponibles y pruebas de carga antes de producción.
- El frontend debe implementar autenticación Entra y actuar como proxy del backend. El backend debe aplicar autorización por operación. Se requieren imágenes privadas por digest, pruebas de rechazo anónimo y control de cargas/streaming; este traslado no inventa ni publica código de aplicación.
- Los IDs de zonas DNS centrales deben confirmarse; plataforma debe publicar por separado el dominio interno ACA y el nombre web. Requiere AMPLS corporativo y certificado TLS en Key Vault.
- La creación de runtime no implica que un agente esté operativo: verificar capability hosts, conexiones AAD, permisos de persistencia, modelos y ejecución real. Runtime puede prepararse sin modelo; la aplicación exige modelo explícito y aprobado.
- Defender Storage no bloquea automáticamente documentos: confirmar que la aplicación espera análisis válido. Planes de seguridad activos no certifican cobertura de todas las operaciones de IA, runtime ACA, SIEM o detección efectiva.
- `validate`, `what-if`, DNS/rutas, RBAC efectivo y pruebas de aplicación no se han ejecutado en un destino Azure durante este traslado. Al actualizar instalaciones existentes, ARM incremental conserva roles antiguos y recursos omitidos; inventariar y revocar permisos amplios mediante el procedimiento acordado.

Se mantienen los límites acordados: no añadir Bastion, firewall, VPN Gateway, DNS Resolver o APIM nuevos; Purview, SharePoint y guardrails pertenecen al hub. Los documentos CAF del usuario son referencias arquitectónicas, no evidencia de que estas integraciones estén operativas.

## Validación del traslado

Compilación/linter de la entrada, 22 pruebas locales, rechazo de parámetros de ejemplo incompletos y comparación byte a byte de módulos/NSG con el origen. Las pruebas cubren reparto del `/24`, rutas permitidas y denegadas, condiciones entre etapas, permisos, límites de escalado y fallos de configuración Defender. No equivalen a una auditoría exhaustiva ni a validación del proveedor en Azure.

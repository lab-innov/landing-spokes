# Revisión ECOCAF frente a CAF y las nuevas pautas de seguridad

Se revisó el código de `ecocaf-spoke` frente a `CAF_Plan_Hub_IA_Spokes.pdf`
(secciones 3-6, 8 y 10-11) y `DDA_Azure_AI_Landing_Zone_CAF.pdf`
(secciones 6.2, 7.1-7.3, ADR-01/02/03 y 9-10), junto con los acuerdos vigentes.
Son referencias de diseño; las fechas, disponibilidad y estados «Implementado»
no acreditan el estado actual de CAF ni autorizan cambios corporativos.

## Hallazgos y tratamiento

| Tema | Hallazgo | Cambio o decisión |
| --- | --- | --- |
| Inventario | El RG `RG-POC-ECOCAF-CR` solo contiene Function, plan y host Storage; las dependencias están compartidas en `RG-POC-iDataFactory-CR` | Se modela la aplicación completa en recursos dedicados, sin modificar el origen |
| IA y datos | El documento y los ajustes vivos confirman Blob HNS `ecocaf`, Cosmos `EcoCAF`/`Auditoria`, OpenAI y Document Intelligence | Se crean cuentas dedicadas privadas con identidad/RBAC; modelos y activación quedan bloqueados hasta aprobación y migración |
| Frontend | La interfaz actual forma parte de un App Service compartido | Se crea frontend dedicado Node 24/B1, privado, con Entra e integración VNet; se activa solo con paquete y pruebas confirmados |
| APIs comunes | Auditoría, notificaciones y conversión PDF son contratos HTTP compartidos | No se duplican; requieren URLs privadas verificadas antes de activar |
| ADF/Databricks | La guía los menciona usando nombres de Vinculador/iDataFactory | Se excluyen: no existe evidencia técnica de uso por ECOCAF |
| Topología | Plan propone VNet compartida, admite VNet por iniciativa; esta variante ya tiene VNet propia | Se conserva la migración paralela con tres subredes: endpoints, integración Function e integración frontend. Confirmar destino/IPAM con CAF |
| Rutas | Bicep creaba tabla local a partir de IP del firewall | Se sustituye `firewallPrivateIp` por `routeTableResourceId` existente. CAF conserva control de rutas |
| NSG | Reglas predeterminadas permitían más tráfico que la regla HTTPS visible | Se permite solo tráfico definido para integración y endpoints, con denegación final |
| Conectividad/DNS | Producción no admite peering y cada endpoint requiere DNS central | Se retira el peering y el DNS personalizado; plataforma crea la conexión Virtual WAN y el Bicep enlaza cada endpoint a IDs de zonas existentes |
| Asociación de endpoints | La Function aparecía sin Private Endpoint asociado y había endpoints sin DNS | Se asocian host Blob/Queue/Table, datos Blob/DFS, Cosmos Sql, OpenAI account, Document Intelligence account y sites de Function/frontend; todos usan zonas centrales existentes |
| Entra | Autenticación obligatoria sin lista de identidades autorizadas | Se añade allowlist por object ID y se bloquea activación incompleta |
| Roles | Table Data Contributor se asignaba siempre al host | Se exige necesidad explícita de tablas/bindings; Blob Data Owner se conserva para AzureWebJobsStorage |
| Defender | Sin configuración ni comprobación | Ambos Storage heredan Defender; el preflight revisa AppServices, CloudPosture, AI, CosmosDbs y endpoints aprobados de Function/frontend |
| Auditoría | Blob y cuenta con diagnóstico; Queue/Table sin diagnóstico propio | Se añaden logs de datos y opción de envío al Event Hub existente |
| Alertas | No había alertas propias | Errores HTTP y volumen de solicitudes al Action Group corporativo |
| Application Insights | No permitido por CAF para esta carga | Se retira la connection string; Dynatrace se coordina fuera de esta plantilla |
| Etiquetas | Faltaban departamentos obligatorios | Se exige `OpsDept=DTI` y un `UserDept` no vacío |
| Recuperación | LRS, una instancia, retención 7 días | Se conserva capacidad; recuperación de blobs/contenedores a 14 días y versiones cuando no es HNS. No se declara HA ni DR |
| Configuración | Ajustes de host podían introducir variantes de conexión | Contratos rechazan redefinir AzureWebJobsStorage y ajustes básicos del runtime; se conserva carácter secure |

## Decisiones pendientes de plataforma y aplicación

- **APIM:** el Plan prefiere productos a nivel de servicio y el DDA ws-ai/gw-ai
  con contingencia. Se reutilizará la solución corporativa que confirme CAF;
  este Bicep no crea APIM ni implementa productos, cuotas o routing de modelos.
- **Servicios de datos/IA:** aprobar nombres definitivos, modelo/versiones/capacidad,
  migración de datos y compatibilidad del código con identidad administrada. El
  Bicep reproduce contratos observados, no ejecuta la migración.
- **Archivos:** los documentos se ubican en el Storage HNS dedicado. Confirmar que
  el análisis antimalware cubra ese flujo y bloquee procesamiento hasta resultado
  limpio; habilitar Defender no demuestra por sí solo esa conducta.
- **Secretos:** Key Vault dedicado cuando se confirme un consumidor. Las referencias
  a vault existente requieren permisos y conectividad explícitos; no se inventan.
- **Disponibilidad:** el plan se actualiza a P1v4 de una instancia y Storage LRS
  se conserva. Confirmar disponibilidad de Premium V4 en la unidad de despliegue y revisar ZRS,
  escalado, RTO/RPO y recuperación según clasificación y carga, antes de producción.
- **Observabilidad:** CAF verifica AMPLS, recepción SOC, Activity Logs, alertas
  Defender y retención central. El DDA pide 90 días online y siete años archivados;
  la plantilla no configura ni acredita esa retención.
- **Purview, SharePoint y guardrails:** quedan en el hub por acuerdo del usuario;
  su efectividad no se acredita con esta revisión.
- **AVM:** esta variante conserva módulos locales. La recomendación AVM del DDA
  no equivale a certificación de estos módulos; registrar excepción o migración
  si plataforma exige exclusivamente AVM.

## Evidencia y límites de entrega

Compilación y linter, parámetros de ejemplo compilables pero no desplegables,
pruebas de contratos, restricciones de red y ausencia de recursos públicos/DNS
nuevos. Se ejecutó inventario Azure de solo lectura. No se ejecutaron `az deployment
group validate`, what-if, despliegue ni pruebas funcionales. El código, los datos y
los recursos originales no se modificaron.

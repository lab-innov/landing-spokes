# Revisión ECOCAF frente a CAF y las nuevas pautas de seguridad

Se revisó el código de `ecocaf-spoke` frente a `CAF_Plan_Hub_IA_Spokes.pdf`
(secciones 3-6, 8 y 10-11) y `DDA_Azure_AI_Landing_Zone_CAF.pdf`
(secciones 6.2, 7.1-7.3, ADR-01/02/03 y 9-10), junto con los acuerdos vigentes.
Son referencias de diseño; las fechas, disponibilidad y estados «Implementado»
no acreditan el estado actual de CAF ni autorizan cambios corporativos.

## Hallazgos y tratamiento

| Tema | Hallazgo | Cambio o decisión |
| --- | --- | --- |
| Inventario | Exportación parcial: Function/host Storage; la documentación funcional confirma frontend, Blob de negocio, Cosmos, OpenAI y Document Intelligence | Se conserva una fundación limitada y se exige completar contratos reales antes de ampliar o activar |
| IA y datos | El documento técnico confirma OCR, análisis con modelo y persistencia por fases | Confirmar cuentas, modelos, contenedores, partición, identidad y migración; no copiar claves históricas |
| ADF/Databricks | La guía los menciona usando nombres de Vinculador/iDataFactory | Tratar como pendiente de atribución a ECOCAF; no crear por una referencia mezclada |
| Topología | Plan propone VNet compartida, admite VNet por iniciativa; esta variante ya tiene VNet propia | Se conserva la migración paralela con dos subredes. Confirmar destino/IPAM con CAF; no se impone /24 |
| Rutas | Bicep creaba tabla local a partir de IP del firewall | Se sustituye `firewallPrivateIp` por `routeTableResourceId` existente. CAF conserva control de rutas |
| NSG | Reglas predeterminadas permitían más tráfico que la regla HTTPS visible | Se permite solo tráfico definido para integración y endpoints, con denegación final |
| Conectividad/DNS | Producción no admite peering y cada endpoint requiere DNS central | Se retira el peering y el DNS personalizado; plataforma crea la conexión Virtual WAN y el Bicep enlaza cada endpoint a IDs de zonas existentes |
| Entra | Autenticación obligatoria sin lista de identidades autorizadas | Se añade allowlist por object ID y se bloquea activación incompleta |
| Roles | Table Data Contributor se asignaba siempre al host | Se exige necesidad explícita de tablas/bindings; Blob Data Owner se conserva para AzureWebJobsStorage |
| Defender | Sin configuración ni comprobación | Se habilita configuración del Storage de host heredada de CAF; script revisa AppServices/CloudPosture y host Storage |
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
- **Servicios de datos/IA:** recuperar app settings sin divulgar valores, revisar
  código/pipeline y relacionar cada dependencia con propietario, red, identidad,
  permisos y plan de protección. Los nombres de las 23 rutas no identifican un SDK.
- **Archivos:** identificar el almacenamiento de documentos. Defender sobre el
  Storage de host no protege automáticamente archivos externos ni llamadas HTTP
  que procesan archivos en memoria. Diseñar el control de análisis en la ruta real.
- **Secretos:** Key Vault dedicado cuando se confirme un consumidor. Las referencias
  a vault existente requieren permisos y conectividad explícitos; no se inventan.
- **Disponibilidad:** P1v3 de una instancia y Storage LRS se conservan. Revisar ZRS,
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
nuevos. No se ejecutaron inventario Azure, validate, what-if, create ni pruebas
funcionales. El código y los datos originales permanecen fuera de esta revisión.

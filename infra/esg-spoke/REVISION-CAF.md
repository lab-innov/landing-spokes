# Revisión ESG frente a documentos CAF

Revisión del código de la rama `esg-spoke`; no es una inspección de recursos
Azure ni certifica los estados «Implementado» de los documentos de agosto.

## Referencias y criterio

- `CAF_Plan_Hub_IA_Spokes.pdf`, 11/08/2026: secciones 3-6 (topología y reparto),
  8 (aceptación), 10-11 (operación y evolución de APIM).
- `DDA_Azure_AI_Landing_Zone_CAF.pdf`, agosto de 2026: secciones 7.1-7.3
  (red, identidad, Defender y SIEM), ADR-01/02/03 y secciones 9-10.
- Guía de agentes Bicep y acuerdos vigentes de ESG: migración paralela,
  servicios conservados, DNS de CAF, no push ni despliegue en esta revisión.

Los documentos se usan como referencias arquitectónicas. Sus cronogramas,
precios, disponibilidad regional y afirmaciones de implementación no se toman
como instrucciones de ejecución ni como evidencia actual. ESG no es una de las
tres iniciativas del calendario del Plan: se aplican sus principios, sin copiar
su inventario automáticamente.

## Comparación y decisiones

| Tema | Documento / hallazgo anterior | Resultado de la revisión |
| --- | --- | --- |
| Red | Plan admite VNet compartida o por iniciativa; ESG usa cinco subredes | Se conserva VNet propia y CIDR de IPAM. No se reduce a /24 |
| Centralización | Plan propone Databricks/ADF/IA compartidos; DDA describe otras fronteras de iniciativa | Se conserva inventario ESG por el acuerdo existente. Confirmar si debe consumir servicios centrales antes de producción |
| APIM | Plan: productos a nivel de servicio; DDA: ws-ai/gw-ai con contingencia | Reutilizar APIM corporativo sigue pendiente. No se crea gateway ni se elige una variante sin contrato de plataforma |
| DNS/VPN | Hub y resolución privada corporativos | Se añade DNS explícito a VNet y parámetro para tránsito del gateway remoto; plataforma completa el lado hub |
| NSG | Una regla de endpoints permitía todo desde VirtualNetwork; otras subredes tenían reglas vacías | Se limita origen/destino/puerto en Foundry, Functions y endpoints, con denegación final |
| Databricks | Reglas insertadas por delegación y requiredNsgRules=AllRules | Se preservan reglas del servicio. No se afirma deny-all completo en esas dos subredes; revisar reglas efectivas y segmentación con plataforma |
| Identidad | Function autenticaba tokens pero sin lista de personas/aplicaciones autorizadas | Se añade allowlist por object ID; API detenida hasta completar su contrato de activación |
| Permisos | Acceso a toda la cuenta de datos y a todo Cosmos | Blob limitado a los dos contenedores ESG y Cosmos a esg-db; permisos extra del host son opciones explícitas |
| Auditoría | Storage tenía categoría audit a nivel de cuenta, sin logs de datos | Métricas en cuenta y allLogs en Blob/Queue/Table; envío opcional a Event Hub existente |
| Defender | Sin configuración ni verificación de cobertura | Configuración de ambas cuentas propias y preflight de planes corporativos; no se crea pricing de suscripción desde el spoke |
| Archivos | Ningún contrato para esperar análisis | Se exige evidencia de análisis/control de procesamiento por defecto; la aplicación y notebooks deben implementarlo |
| Operación | Sin alertas propias ni evidencia para iniciar triggers | Alertas de errores HTTP y volumen de solicitudes al Action Group; script de arranque exige constancia vigente |
| Modelos | Selecciones implícitas y actualización automática de versión | Listas vacías por defecto y confirmación explícita; selecciones históricas en ejemplo, sin sustituir modelos |
| Cifrado/recuperación | Storage ZRS y Cosmos backup continuo; retención Blob 7 días | Se mantienen HTTPS, TLS y cifrado Azure; Blob con versiones y recuperación de 14 días |
| Resiliencia | Function EP1 de una instancia, Cosmos serverless sin redundancia zonal | Se conserva dimensionamiento. No hay SLA compuesto ni DR regional demostrado; requiere decisión por criticidad |
| AVM | DDA recomienda AVM; ESG ya tiene módulos adaptados locales | Se conserva procedencia y se valida el código local. Migración a AVM pendiente si plataforma la exige |

## Brechas que requieren trabajo separado

1. **APIM:** contrato de API, identidad, producto, cuota y medición de tokens;
   comprobar que las llamadas reales atraviesan el gateway corporativo. Los
   endpoints directos de los servicios no implementan ese recorrido.
2. **Foundry Agent Service:** cuenta/proyecto e inyección de red no completan un
   runtime privado Standard. ESG no define persistencia exclusiva con Search,
   conexiones ni capability host de proyecto. Seleccionar el modo y recursos
   cuando el flujo real de agentes esté confirmado; no declarar agentes operativos.
3. **Aplicación:** repositorio no contiene código Function ni notebooks. Confirmar
   Python/runtime, paquete privado, bindings, permisos, autenticación por usuario,
   salidas de scraping y bloqueo de archivos no analizados. No se publica aplicación.
4. **Seguridad CAF:** clasificación real, PIM, políticas heredadas, auditoría de
   suscripción, cobertura por recurso, exclusiones Defender y recepción en Taegis.
5. **Secretos:** no se agrega Key Vault sin un consumidor definido. Si ESG necesita
   secretos propios, debe incorporarse un vault dedicado o un contrato corporativo
   explícito con permisos mínimos. Grounding conserva su conexión de clave del
   servicio, dentro de una excepción expresa; no es keyless completo.
6. **Recuperación/carga:** definir RTO/RPO, restauración, capacidad de Functions,
   Cosmos y Databricks. El análisis no convierte la base actual en alta disponibilidad.
7. **Purview, SharePoint y guardrails:** fuera de esta implementación por acuerdo
   del usuario; integración a través del hub, cuya efectividad debe verificarse.

## Evidencia local y alcance

La suite compila ambos puntos de entrada y ambos ejemplos, ejecuta linter y prueba
contratos sobre ARM generado y parámetros válidos/inválidos. Los ejemplos con
marcadores se rechazan. No se ejecuta validate/what-if/create en Azure sin datos
reales. Los cambios se registran localmente en Git y no alteran el RG original.

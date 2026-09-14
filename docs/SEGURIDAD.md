# Seguridad común y ajustes por solución

La base aplica red privada, segmentación, identidades separadas, cifrado y auditoría.
Cada solución debe registrar clasificación de información, propietario, riesgos,
destinos externos, requisitos de recuperación y excepciones antes de producción.
Purview, SharePoint y guardrails quedan en el ámbito del hub, según el acuerdo.
Esta plantilla no acredita su integración ni una aceptación corporativa completa.

## Qué controla el spoke

Un NSG es una lista de conexiones permitidas para una subred: origen, destino y
puerto. No autentica usuarios ni analiza archivos. Los cuatro NSG terminan con
una denegación explícita de tráfico no autorizado, antes de los permisos generales
predeterminados de Azure. Las respuestas de conexiones permitidas son stateful.

| Origen | Destino permitido | Uso |
| --- | --- | --- |
| Clientes VPN declarados | Gateway, TCP 443 | Web privada |
| Gateway | ACA, TCP 443/31443 | Frontend y puerto de infraestructura requerido por ACA |
| Gateway | IP del endpoint de Key Vault, TCP 443 | Certificado |
| Foundry y ACA | Endpoints del spoke, TCP 443 | Servicios privados; RBAC restringe los datos |
| Foundry | IP reales de Cosmos, TCP 0-65535 | Acceso directo Cosmos por Private Link |
| Operadores/ejecutores declarados | Endpoints, TCP 443 | Publicación y administración autorizadas |
| Foundry/ACA | Misma subred | Comunicación interna del servicio administrado |
| Azure Load Balancer | Sondas del servicio | Salud de infraestructura |
| Subredes de cómputo/gateway | DNS configurado y DNS de Azure, puerto 53 | Resolución |
| Foundry/ACA | Etiquetas AAD, MCR, AzureFrontDoor.FirstParty, AzureMonitor y Storage.EastUS, TCP 443 | Dependencias de plataforma |
| Subredes de cómputo/gateway | IP de AMPLS, TCP 443 | Telemetría privada |

Las etiquetas de Azure abarcan más destinos que esta solución. El firewall CAF
completa el filtro por dominios; validar sus reglas, rutas de retorno y dependencias
antes de activar. La plantilla no crea ni modifica ese firewall. No interceptar TLS
de Foundry con certificados no admitidos. El aislamiento entre frontend y backend
del mismo entorno ACA depende del ingreso de ACA y de la aplicación, no del NSG.
El frontend admite solo la subred del gateway; el backend tiene ingreso interno.

`operatorPrefixes` debe contener solo ejecutores/operadores autorizados, no toda
la VPN. `monitorPrefixes` contiene IP/CIDR privados de AMPLS. `extraEgress` permite
excepciones TCP documentadas por solución: IP/CIDR /24 o más específico, puertos
individuales y justificación de hasta 140 caracteres. El comprobador rechaza
Internet genérico y excepciones de endpoints. No hay salida general a Internet.
Cambios de direcciones de APIs externas deben gestionarse con plataforma.

Después de crear la fundación, descubrir `privateServiceAddresses.vault` y
`.cosmos` con el preflight y verificar que pertenecen al endpoint de esta solución.
No se inventan IP estáticas. Sin esos datos no se abre la regla correspondiente;
Cosmos es obligatorio para activar runtime y Key Vault para activar gateway.
Un cambio/recreación del endpoint exige volver a descubrir IP y actualizar reglas.

## Defender y responsabilidad de CAF

Se crean dos configuraciones `Microsoft.Security/defenderForStorageSettings`, con
`isEnabled=true`, que conservan la herencia de suscripción. No se crean planes
`Microsoft.Security/pricings` desde el spoke ni se sobrescriben opciones corporativas.
CAF debe tener habilitados los planes que correspondan y revisar su facturación.

| Protección | Configuración y evidencia requerida |
| --- | --- |
| Ambos Storage | Defender habilitado en configuración efectiva |
| Archivos `uploads` | `scanUploads=true` exige malware scanning efectivo y límite mensual revisado por CAF |
| Key Vault | Plan KeyVaults Standard y alertas integradas al SOC |
| Cosmos | Plan CosmosDbs Standard para API NoSQL |
| Foundry | Plan AI Standard; comprobar cobertura real de operaciones usadas |
| Imágenes ACR | Containers o CloudPosture Standard con ContainerRegistriesVulnerabilityAssessments; comprobar un digest analizado |
| ACA | CloudPosture Standard para postura serverless; no implica detección de amenazas en ejecución equivalente a AKS |

ACR mantiene `publicNetworkAccess=Disabled`, pero permite `AzureServices` para
que Defender acceda como servicio de confianza. Esta excepción de red requiere
identidad/autorización; no abre el registro a usuarios anónimos.

El preflight es de solo lectura:

```bash
python3 scripts/check_security.py --resources /ruta/privada/recursos-seguridad.json
```

El JSON contiene el **valor** del output `securityResourceIds` (mapa de IDs).
El script consulta la suscripción derivada de esos IDs, no cambia planes y falla
si no puede leerlos. Entrega IP de endpoints aprobados y carencias detectadas.
No exporta tokens ni claves. Requiere permisos de lectura de seguridad y red.
`--no-upload-scanning` corresponde únicamente a una solución con `scanUploads=false`
y evaluación de riesgo documentada. No deshabilita un análisis que CAF ya exija.

El informe comprueba configuración, no prueba detección: revisar exclusiones,
asignaciones de política, cobertura y hallazgos sobre estos recursos en Defender.
Probar escaneo de un digest y un archivo de prueba aprobado por seguridad.
Solo con evidencia vigente marcar `defenderCoverageVerified=true`.

Malware scanning añade recursos administrados por Microsoft, como el tema de
Event Grid del sistema, identidad del scanner y permisos sobre blobs. CAF debe
permitirlos y comprobar que sucesivos despliegues/políticas no rompen sus ACL/RBAC.
No se crea aquí un tema público personalizado para resultados.
El límite mensual puede dejar archivos sin analizar: la aplicación debe rechazar
procesamiento de archivos pendientes, no analizados, con error o maliciosos.
Las etiquetas de blobs son modificables y no deben ser la única evidencia de
seguridad. Definir con el hub un canal confiable de resultados; confirmar el
comportamiento real mediante `uploadGateVerified=true` antes de activar la web.
La imagen de la aplicación debe implementar ese control; este Bicep no lo implementa.

## Identidad, permisos y cifrado

Backend: rol sobre el proyecto Foundry y datos del contenedor `uploads`;
`backendSecretNames` concede lectura solo de secretos existentes enumerados.
Frontend/backend: `AcrPull`. Gateway: lectura solo del secreto de su certificado.
El proyecto utiliza roles de persistencia necesarios para el runtime Standard.
No asignar Owner/Contributor de suscripción para ejecutar la aplicación.
La autenticación Entra y autorización por usuario siguen siendo requisitos de las imágenes.

HTTPS/TLS mínimo 1.2 donde se configura; Storage cifra en reposo con claves de
Microsoft, deshabilita claves compartidas y acceso anónimo, y mantiene recuperación.
No se incorporan CMK por defecto: su necesidad depende de clasificación y política.
La redundancia zonal no sustituye una estrategia de recuperación regional; acordar
RTO/RPO y probar restauración según cada solución.

## SIEM y operación

Los diagnósticos existentes siguen enviándose al Log Analytics corporativo.
Opcionalmente, `siemAuthorizationRuleId` y `siemEventHubName` envían además los
logs a un Event Hub corporativo existente. Introducir ambos o ninguno; el ID es
de una regla del namespace compatible con diagnósticos (Manage/Send/Listen),
no una clave. Verificar región, acceso de servicios de confianza y permisos para
configurar diagnósticos. No se crea ni se modifica el namespace.

SOC administra el conector/pipeline de Log Analytics o Event Hub al SIEM, los
Activity Logs de suscripción y la exportación de alertas Defender. Son flujos
separados de los diagnósticos de recursos. Probar la llegada de eventos con ID
correlacionable, alertas y tiempos de retención. Marcar `siemDeliveryVerified=true`
solo después de recibir evidencia del SOC; el script no marca ese indicador.
No registrar secretos ni contenido sensible de prompts/archivos sin una política.

## Actualización de infraestructura existente

Ejecutar comprobador, validate y what-if antes de aplicar. Revisar si los Storage
existentes tienen una excepción local de Defender: esta variante restaura la
herencia de suscripción, por lo que CAF debe confirmar que no reduce su protección. Preparar IP reales,
excepciones, AMPLS y acceso del ejecutor antes de cerrar NSG; verificar DNS, descarga
de imágenes, persistencia, certificado y telemetría desde CAF. La validación local
no demuestra que las rutas y políticas corporativas acepten estas reglas.

La nueva plantilla deja de conceder lectura completa del vault a backend/gateway.
**ARM incremental conserva las asignaciones antiguas.** Inventariar asignaciones
directas y heredadas de ambas identidades, probar las nuevas asignaciones por
secreto y revocar explícitamente las antiguas con el propietario autorizado.
No declarar mínimo privilegio efectivo mientras subsistan permisos más amplios.
Omitir una asignación o poner una etapa en false no la elimina ni hace rollback.

## Referencias

- [NSG y dependencias ACA](https://learn.microsoft.com/azure/container-apps/firewall-integration).
- [Red de Foundry](https://learn.microsoft.com/azure/foundry/agents/how-to/virtual-networks).
- [ACR privado y Defender](https://learn.microsoft.com/azure/container-registry/scan-images-defender).
- [Postura de contenedores serverless](https://learn.microsoft.com/azure/defender-for-cloud/posture-for-serverless-containers).
- [Herencia de configuración de malware](https://learn.microsoft.com/azure/defender-for-cloud/advanced-configurations-for-malware-scanning).
- [Resultados y limitaciones del análisis](https://learn.microsoft.com/azure/defender-for-cloud/introduction-malware-scanning).

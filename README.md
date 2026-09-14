# Foundry Agent — spoke privado CAF

Patrón de agentes administrados Foundry Standard con frontend/backend en Container Apps, ACR y Application Gateway WAF privado. East US, una VNet `/24`, VPN del hub, DNS/DINE y observabilidad corporativos.

Entrada: [infra/main.bicep](infra/main.bicep). Ejemplo: [parámetros](environments/main.parameters.example.json), con marcadores que deben sustituirse fuera de Git.

- [Alineación con los otros spokes](docs/REVISION-CAF.md).
- [Etapas y dependencias de despliegue](docs/DESPLIEGUE.md).
- [Seguridad y Defender](docs/SEGURIDAD.md).
- [Procedencia del traslado](references/ORIGEN.md).

Validación local: `scripts/validate.sh`. Compilación y linter sin avisos; 22 pruebas correctas. No se ha desplegado en Azure ni publicado imágenes de aplicación.

La fundación deja las etapas inactivas y los modelos vacíos. Requiere clasificación; los modelos necesitan aprobación explícita y la activación exige un identificador de aprobación. El `/24` queda completo y necesita pruebas de capacidad. Autenticación de las imágenes, DNS, AMPLS, certificado, cuotas y cobertura efectiva de Defender siguen siendo condiciones operativas.

# Landing Spokes

Infraestructura Azure por solución. La [guía de IFISCAF](infra/ifiscaf-spoke/README.md)
describe el despliegue paralelo y la integración con el hub corporativo.

Copia y completa los parámetros antes de validar:

```bash
cp environments/ifiscaf-spoke/ifiscaf-spoke.example.bicepparam environments/ifiscaf-spoke/dev.bicepparam
./scripts/deploy-ifiscaf-spoke.sh environments/ifiscaf-spoke/dev.bicepparam validate
./scripts/deploy-ifiscaf-spoke.sh environments/ifiscaf-spoke/dev.bicepparam what-if
```

Solo la acción explícita `create` despliega recursos.

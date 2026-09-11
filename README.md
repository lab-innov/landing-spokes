# Spokes de CAF

Esta rama contiene el [spoke privado ESG](infra/esg-spoke/README.md), preparado
para migración paralela sin modificar `RG-POC-ESG-CR`.

Consultar la [revisión CAF y seguridad](infra/esg-spoke/REVISION-CAF.md) para
controles implementados, responsabilidades corporativas y decisiones pendientes.

```bash
./tests/esg-spoke-contracts.sh
```

La validación local no despliega recursos ni acredita cumplimiento en Azure.

# Landing Spokes

This repository contains workload-specific Azure landing-zone spokes.

## ESG secure spoke

The ESG implementation is under [infra/esg-spoke](infra/esg-spoke/README.md).
It deploys a parallel private spoke integrated with a corporate hub and keeps
the existing `RG-POC-ESG-CR` resources unchanged for rollback.

Start by copying and completing the example parameter file:

```bash
cp environments/esg-spoke/esg-spoke.example.bicepparam environments/esg-spoke/dev.bicepparam
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam validate
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam what-if
```

No deployment is performed until the explicit `create` action is used.

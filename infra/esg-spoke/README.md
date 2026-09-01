# ESG Secure Landing-Zone Spoke

This deployment creates a new, private ESG workload spoke without modifying the
existing `RG-POC-ESG-CR` resources. It is designed for an Azure landing-zone
subscription connected to a platform-owned corporate hub.

## What is deployed

- A spoke VNet and one-way spoke-to-hub peering.
- Dedicated private endpoint, Foundry agent, Function integration, and two
  Databricks VNet-injection subnets.
- A platform-provided route table on every subnet and an NSG per subnet.
- Microsoft Foundry account/project, model deployments, and optional Grounding
  with Bing Search.
- A separate Azure OpenAI account and Document Intelligence account.
- Premium Azure Databricks with secure cluster connectivity and an access
  connector.
- Azure Data Factory with managed VNet and managed private endpoints.
- Workload and Function host storage accounts, Cosmos DB, Application Insights,
  and a private Entra-authenticated Linux Function App host.
- Private endpoints without private DNS zone groups. Corporate DINE policy owns
  the zone-group and central DNS integration lifecycle.

The implementation adapts selected patterns from
`Azure/bicep-ptn-aiml-landing-zone` at commit
`bfbcd97f276cba132c30ec4d33f1baa27098af29`. The resulting modules are local to
this deployment and can evolve independently.

## Platform prerequisites

The platform team must provide:

1. A corporate hub VNet resource ID and permission to create the spoke-side
   peering. The platform team creates the reverse peering.
2. An existing route table resource ID with the approved default route and
   service/FQDN rules. It is attached to every spoke subnet.
3. A central Log Analytics workspace and Azure Monitor Private Link Scope. The
   platform team must associate the new Application Insights component with the
   AMPLS because public ingestion and query are disabled.
4. DINE policy assignments and DNS Private Resolver links for these namespaces:
   `privatelink.services.ai.azure.com`, `privatelink.openai.azure.com`,
   `privatelink.cognitiveservices.azure.com`, `privatelink.blob.core.windows.net`,
   `privatelink.queue.core.windows.net`, `privatelink.table.core.windows.net`,
   `privatelink.documents.azure.com`, `privatelink.azurewebsites.net`,
   `privatelink.datafactory.azure.net`, `privatelink.adf.azure.com`, and
   `privatelink.azuredatabricks.net`.
5. Corporate-IPAM-approved, non-overlapping CIDRs. The example `/21` is not an
   allocation request or a production default.
6. An Entra application registration for the private Function API.

Grounding with Bing Search is the supported replacement for the retired Bing
Search API. It is enabled only when the parameter file contains an approved
governance exception ID. The exception acknowledges that Grounding traffic uses
public service egress even from a network-isolated Foundry project.

## Deployment stages

Copy the example parameter files to new filenames ending in `.bicepparam` and
replace every placeholder.

### 1. Secure infrastructure

```bash
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam validate
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam what-if
./scripts/deploy-esg-spoke.sh environments/esg-spoke/dev.bicepparam create
```

The deployment outputs the generated service names, resource IDs, private
endpoints, managed identities, Foundry endpoint, Databricks URL, and required
platform follow-up actions.

### 2. Databricks notebooks and cluster

Follow [the Asset Bundle handoff](databricks/README.md). The bundle pipeline must
return an interactive cluster ID after publishing both notebooks.

### 3. Data Factory assets

Populate `adf-assets.bicepparam` from stage 1 outputs and the cluster ID:

```bash
./scripts/deploy-esg-adf-assets.sh rg-esg-secure-spoke-dev environments/esg-spoke/adf-dev.bicepparam validate
./scripts/deploy-esg-adf-assets.sh rg-esg-secure-spoke-dev environments/esg-spoke/adf-dev.bicepparam what-if
./scripts/deploy-esg-adf-assets.sh rg-esg-secure-spoke-dev environments/esg-spoke/adf-dev.bicepparam create
```

This stage creates the MSI-authenticated Databricks linked service, the two
pipelines, and the two trigger definitions. It never starts the triggers.

### 4. Cutover

After private DNS, endpoint approvals, data migration, notebook execution, and
manual pipeline tests succeed:

```bash
./scripts/set-esg-adf-triggers.sh rg-esg-secure-spoke-dev <factory-name> start
```

Use the same command with `stop` for rollback. Keep the original resource group
unchanged until reconciliation and rollback acceptance are complete.

## What is intentionally excluded

- Function application source/package deployment.
- Blob and Cosmos DB data migration.
- Reverse hub peering, central DNS zones, DINE policy assignments, firewall
  rules, and AMPLS association.
- Databricks notebook contents and workspace data-plane permissions. These are
  owned by the Asset Bundle pipeline.
- Exported deployment history, Function child snapshots, built-in RAI policies,
  system Cosmos role definitions, and opaque Event Grid webhook resources.

## Local validation

```bash
./tests/esg-spoke-contracts.sh
```

The contract suite compiles both entry points and rejects hard-coded
subscription IDs, retired Bing Search resources, enabled public access, local
AI authentication, or deployment-owned private DNS zone groups.

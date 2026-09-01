# Databricks Asset Bundle handoff

Notebook source is not present in this repository, so infrastructure deployment
stops at the secured workspace and access connector. The application repository
must own a Databricks Asset Bundle that:

1. Targets the `databricksWorkspaceUrl` output from `main.bicep`.
2. Publishes these workspace paths:
   - `/Repos/iData/Caf-esg-model/model_processing`
   - `/Repos/iData/Caf-esg-model/scioteca_webscraping`
3. Creates or selects an interactive cluster compatible with both notebooks.
   The cluster must use the VNet-injected workspace, have no public IP, and use
   an approved runtime/node policy.
4. Assigns the Data Factory managed identity to the workspace and grants it
   permission to attach to and restart the interactive cluster. The ARM
   Contributor assignment created by Bicep does not replace Databricks
   workspace data-plane entitlements.
5. Emits the cluster ID as a protected pipeline output. That value becomes the
   `databricksClusterId` parameter of `adf-assets.bicep`.

The bundle must complete before Data Factory assets are deployed. Do not start
ADF triggers until both notebooks and a manual run of each pipeline succeed.

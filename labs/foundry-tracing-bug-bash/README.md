# Foundry Gateway tracing bug bash

Bug bash for the AI Gateway + Foundry tracing experience. Validate that Gateway
spans can be viewed natively in Foundry.

## Setup

You need:

- Bash, [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), and
  [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
  1.36.0+.
- The `.env` file containing the shared project and
  connection settings. Do not put credentials in this file.

Open a terminal in this directory:

```shell
azd ext install azure.ai.agents
azd ext install azure.ai.projects
azd auth login
az login
cp azure.template.yaml azure.yaml
azd env new tracing-bug-bash
azd env set --file .env
```

Open `azure.yaml` and use your editor's **Replace All** to replace the literal
text `${PARTICIPANT_ALIAS}` with your own lowercase alias, for example
`johnsmith`. There are eight occurrences, one in each agent's `name`. Leave the
service keys and other `${...}` settings unchanged.

## Instructions

### Deploy the agent

Choose an agent:

| Agent name | Type | Operation | Tier |
|---|---|---|---|
| `prompt-model-apim` | Prompt | Model | APIM tier |
| `prompt-model-dedicated` | Prompt | Model | Gateway tier |
| `prompt-tool-apim` | Prompt | Tool | APIM tier |
| `prompt-tool-dedicated` | Prompt | Tool | Gateway tier |
| `hosted-model-apim` | Hosted | Model | APIM tier |
| `hosted-model-dedicated` | Hosted | Model | Gateway tier |
| `hosted-tool-apim` | Hosted | Tool | APIM tier |
| `hosted-tool-dedicated` | Hosted | Tool | Gateway tier |

For a prompt variant:

```shell
./deploy-prompt.sh <agent-name>
```

For a hosted variant:

```shell
azd deploy <agent-name>
```

Examples: `./deploy-prompt.sh prompt-tool-dedicated` or `azd deploy hosted-tool-dedicated`.

Both commands create agents prefixed with the alias you set in `azure.yaml`.

#### Use existing agents

If you run into deployment issues, you can use the existing `kevindestin-` agents
in the shared project.

## Run and inspect

Open your agent's playground in Foundry.

**Model prompt:**

> What is an API gateway?

**Tool prompt:**

> Use the documentation search tool to find the Microsoft Learn article
> "Set up tracing in Microsoft Foundry". Return its documentation URL.

Open **Agents > Traces** and select your run.

| Operation | Expected relationship |
|---|---|
| Model | Agent -> chat -> Gateway model request -> backend |
| Tool | Agent -> tool execution -> Gateway tool request -> backend |

Inspect operation names, status, duration, and parent-child relationships.

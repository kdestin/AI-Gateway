#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    prompt-model-apim|prompt-model-dedicated|prompt-tool-apim|prompt-tool-dedicated)
        service="$1"
        ;;
    *)
        printf 'Usage: ./deploy-prompt.sh <prompt-model-apim|prompt-model-dedicated|prompt-tool-apim|prompt-tool-dedicated>\n' >&2
        exit 2
        ;;
esac

name=
description=
definition_file=
selected=false
# Read the three literal, single-line fields from this sample's manifest block.
while IFS= read -r line; do
    if [[ "$line" == "  $service:" ]]; then
        selected=true
    elif [[ "$line" == "  "[![:space:]]* ]]; then
        selected=false
    elif [[ "$selected" == true ]]; then
        case "$line" in
            "    name: "*)
                name=${line#'    name: '}
                name=${name#\"}
                name=${name%\"}
                ;;
            "    description: "*) description=${line#'    description: '} ;;
            '    $ref: '*) definition_file=${line#'    $ref: '} ;;
        esac
    fi
done < azure.yaml

if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ || ${#name} -gt 63 ]]; then
    printf 'Replace ${PARTICIPANT_ALIAS} in azure.yaml with your lowercase alias.\n' >&2
    exit 1
fi
if [[ "$definition_file" != "./prompts/$service.json" ]]; then
    printf 'Expected %s to reference ./prompts/%s.json in azure.yaml.\n' "$service" "$service" >&2
    exit 1
fi

endpoint=$(azd env get-value FOUNDRY_PROJECT_ENDPOINT)
subscription=$(azd env get-value AZURE_SUBSCRIPTION_ID)
definition=$(<"$definition_file")

json_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    if [[ "$value" == *[[:cntrl:]]* ]]; then
        printf 'Configuration values must be single-line text without control characters.\n' >&2
        return 1
    fi
    printf '%s' "$value"
}

replace_setting() {
    local key=$1 value
    value=$(azd env get-value "$key")
    value=$(json_escape "$value")
    definition=${definition//"\${$key}"/"$value"}
}

case "$service" in
    *-apim) prefix=APIM ;;
    *-dedicated) prefix=DEDICATED ;;
esac
replace_setting "${prefix}_MODEL"
if [[ "$service" == prompt-tool-* ]]; then
    replace_setting "${prefix}_TOOL_URL"
    replace_setting "${prefix}_TOOL_CONNECTION_ID"
    replace_setting "${prefix}_TOOL_NAME"
fi

description=$(json_escape "$description")
body="{\"description\":\"$description\",\"definition\":$definition}"
url="${endpoint%/}/agents/${name}"
version=$(az rest --method post --url "${url}/versions?api-version=v1" \
    --resource https://ai.azure.com --subscription "$subscription" \
    --body "$body" --query version --output tsv)
printf 'Created %s:%s\n' "$name" "$version"

[[ "$version" =~ ^[0-9]+$ ]]
body="{
    \"agent_endpoint\": {
        \"version_selector\": {
            \"version_selection_rules\": [{
                \"type\": \"FixedRatio\", \"agent_version\": \"$version\", \"traffic_percentage\": 100
            }]
        },
        \"protocol_configuration\": {\"responses\": {}}
    }
}"
az rest --method patch --url "${url}?api-version=v1" \
    --resource https://ai.azure.com --subscription "$subscription" \
    --headers Content-Type=application/merge-patch+json \
    --body "$body" --output none
az rest --method get --url "${url}?api-version=v1" \
    --resource https://ai.azure.com --subscription "$subscription" \
    --query '{name:name,version:versions.latest.version,model:versions.latest.definition.model,tools:versions.latest.definition.tools,endpoint:agent_endpoint.version_selector}' \
    --output json

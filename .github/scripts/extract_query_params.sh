#!/bin/bash

# Fail on any error
set -e

# Best practice is to define all needed tools and exit if they're not installed
type jq >/dev/null 2>&1 || { echo >&2 "jq is required but it's not installed. Aborting."; exit 1; }

# Ensure the manifest file exists
manifest_file="tyk-manifest.json"
if [ ! -f "$manifest_file" ]; then
    echo "Manifest file $manifest_file does not exist."
    exit 1
fi

# Read the content of the manifest file
content=$(<"$manifest_file")

# Build JSON objects for params and api_ids using jq
read -r -d '' json_params json_api_ids < <(jq -c -M '
    reduce (keys[] as $key
    (
        {}; 
        .params[$key] = (.[$key].params | to_entries | map("\(.key)=\(.value|tostring)") | join("&")),
        .api_ids[$key] = .[$key].api_id
    )
)' "$manifest_file")

# Append generated JSON to the GitHub Actions output file
{
    echo "queryParams=${json_params.params}"
    echo "apiIds=${json_api_ids.api_ids}"
} >> "$GITHUB_OUTPUT"

# If desired, show the output (for debugging purposes)
echo "Generated queryParams: $json_params"
echo "Generated apiIds: $json_api_ids"

#!/bin/bash

TOKEN=$1
BASE_URL=$2
PARENT_COMMIT_SHA=$3
QUERY_PARAMS=$4
API_IDS=$5
FILE_REGEX=$6

echo "Start iterating"
git diff-tree --no-commit-id --name-only -r $PARENT_COMMIT_SHA
for file in $(git diff-tree --no-commit-id --name-only -r $PARENT_COMMIT_SHA | grep -E "$FILE_REGEX"); do
    content=$(cat "$file")
    echo "Processing file: $file"
    #echo "File content: $content"
    filename=$(basename -- "$file")
    filename="${filename%.*}"
    echo $FILE_REGEX
    echo $file
    if [[ $file =~ $FILE_REGEX ]]; then
      apiID="${BASH_REMATCH[1]}"
      echo "Extracted ID inside if: $apiID"
    else
      echo "No ID found."
    fi
    echo "Processing file: $file"
    echo "Filename: $filename"
    query_params=$(echo "$QUERY_PARAMS" | jq -r ".[\"$filename\"]")
    echo "QUERY PARAMS"
    echo $query_params
    apiID=$(echo "$API_IDS" | jq -r ".[\"$filename\"]")
    echo "API ID"
    echo $apiID
    importEndpoint="/api/apis/oas/import"
    endpoint="/api/apis/oas/$apiID"
    echo "Endpoint: $BASE_URL$endpoint"
  
    # Check if API exists with a GET request
    echo "Sending GET request to $BASE_URL$endpoint"
    response=$(curl -s -o /dev/null -w "%{http_code}" -X GET -H "Authorization: ${TOKEN}" --location "${BASE_URL}${endpoint}")
    echo "Response: $response"

    if [ $response -eq 200 ]; then
      echo "API with ID $apiID already exists. Performing PATCH request."
      echo "${BASE_URL}${endpoint}"
      response=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -H "Authorization: $TOKEN" -H "Content-Type: application/json" -d "$content" "${BASE_URL}${endpoint}?${query_params}")
      if [ $response -eq 200 ]; then
        echo "API has been patched with a new OAS request succeeded."
      else
        echo "API Patch request failed with status code $response."
      fi
    else
      echo "API with ID $apiID does not exist. Performing IMPORT request."
      echo "${BASE_URL}${importEndpoint}"
      # Add apiID query parameter to the POST request
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Authorization: $TOKEN" -H "Content-Type: application/json" -d "$content" "${BASE_URL}${importEndpoint}?apiID=$apiID&${query_params}")
      if [ $response -eq 200 ]; then
        echo "Import of OAS request succeeded."
      else
        echo "Import of OAS request failed with status code $response."
        echo "Response: $response"
      fi
    fi
done

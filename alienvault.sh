#!/bin/bash

# Check if jq is installed.
if ! command -v jq &>/dev/null; then
  echo "jq is required but not installed. Please install jq and rerun this script."
  exit 1
fi

# Check if domain is provided as an argument.
if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

# Get domain from argument.
domain=$1

# Set initial pagination parameters.
page=1
limit=500

echo "Fetching URLs from AlienVault OTX for domain: $domain"

while true; do
  echo "Fetching page $page..."
  
  # Retrieve the JSON response for the current page.
  response=$(curl -s "https://otx.alienvault.com/api/v1/indicators/hostname/${domain}/url_list?limit=${limit}&page=${page}")
  
  # Extract URLs from the JSON response.
  urls=$(echo "$response" | jq -r '.url_list[]?.url')
  
  # If no URLs were returned, break the loop.
  if [[ -z "$urls" ]]; then
    echo "No more URLs found on page $page. Finishing."
    break
  fi
  
  # Print the retrieved URLs.
  echo "$urls"
  
  # Count how many URLs were returned on this page.
  count=$(echo "$response" | jq -r '.url_list | length')
  echo "Found $count URL(s) on page $page."
  
  # If fewer URLs than the limit were returned, assume it's the last page.
  if (( count < limit )); then
    echo "Reached the last page."
    break
  fi
  
  # Increment page number for the next iteration.
  page=$((page + 1))
done

echo "Done fetching URLs."

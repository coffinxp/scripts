#!/bin/bash

# Check if domain was provided
if [ -z "$1" ]; then
  echo "Usage: $0 domain.com [-s] [-e] [-sc codes] [-scx codes]"
  echo "Examples:"
  echo "  $0 example.com -s -sc 200"
  echo "  $0 example.com -sc 200,302,403"
  echo "  $0 example.com -scx 404,500"
  echo "  $0 example.com -e extensions only"
  exit 1
fi

domain=$1
shift # shift args so $2 becomes the flags

# Defaults
subdomains=false
extensions=false
status_code=""
exclude_status_code=""

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) subdomains=true ;;
    -e) extensions=true ;;
    -sc) status_code=$2; shift ;;   # include codes
    -scx) exclude_status_code=$2; shift ;; # exclude codes
  esac
  shift
done

# Regex for sensitive extensions
ext_regex='xls|xml|xlsx|json|pdf|sql|doc|docx|pptx|txt|git|zip|tar\.gz|tgz|bak|7z|rar|log|cache|secret|db|backup|yml|gz|config|csv|yaml|md|md5|exe|dll|bin|ini|bat|sh|tar|deb|rpm|iso|img|env|apk|msi|dmg|tmp|crt|pem|key|pub|asc'

# Decide base URL
if $subdomains; then
  base_url="https://web.archive.org/cdx/search/cdx?url=*.$domain/*&collapse=urlkey&output=text&fl=original,statuscode"
  echo "Fetching results for $domain including subdomains..."
else
  base_url="https://web.archive.org/cdx/search/cdx?url=$domain/*&collapse=urlkey&output=text&fl=original,statuscode"
  echo "Fetching results for $domain (main domain only)..."
fi

# Add extension filter
if $extensions; then
  echo "Filtering by specific file extensions..."
  base_url="$base_url&filter=original:.*\.($ext_regex)$"
fi

# Add status code include filter
if [ -n "$status_code" ]; then
  status_code_regex=$(echo "$status_code" | sed 's/,/|/g')
  echo "Including only HTTP status code(s): $status_code"
  base_url="$base_url&filter=statuscode:($status_code_regex)"
fi

# Add status code exclude filter
if [ -n "$exclude_status_code" ]; then
  exclude_status_code_regex=$(echo "$exclude_status_code" | sed 's/,/|/g')
  echo "Excluding HTTP status code(s): $exclude_status_code"
  base_url="$base_url&filter=!statuscode:($exclude_status_code_regex)"
fi

# Run query
urls=$(curl -s "$base_url")

# Show results (only URLs, strip status codes)
if [ -z "$urls" ]; then
  echo "No results found."
else
  echo "$urls" | awk '{print $1}'
fi

#!/bin/bash

# Colors
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
RESET='\033[0m'

# ASCII Banner
echo -e "${RED}"
cat << "EOF"
 ______            _____________                              
___  /______________  /___  __/___  _________________________
__  /_  __ \_  ___/  __/_  /_ _  / / /__  /__  /_  _ \_  ___/
_  / / /_/ /(__  )/ /_ _  __/ / /_/ /__  /__  /_/  __/  /    
_/  \____//____/ \__/ /_/    \__,_/ _____/____/\___//_/ 
      
                              by ~/.coffinxp@lostsec
EOF
echo -e "${RESET}"

# ===== Functions =====

usage() {
    echo -e "${YELLOW}Usage: $0 -d domain.com | -l subdomains.txt [-t threads]${RESET}"
    exit 1
}

check_tools() {
    REQUIRED_TOOLS=("gau" "uro" "httpx-toolkit" "nuclei")
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo -e "${RED}[ERROR] $tool is not installed. Please install it and try again.${RESET}"
            exit 1
        fi
    done
}

summary() {
    echo -e "\n${GREEN}===== SUMMARY =====${RESET}"
    echo "Total URLs fetched:   $(wc -l < "$GAU_FILE" 2>/dev/null || echo 0)"
    echo "URLs with params:     $(wc -l < "$FILTERED_URLS_FILE" 2>/dev/null || echo 0)"
    echo "Live URLs:            $(wc -l < "$LIVE_URLS" 2>/dev/null || echo 0)"
    echo "Vulnerabilities:      $(wc -l < "$NUCLEI_RESULTS" 2>/dev/null || echo 0)"
    echo "Results saved in:     $OUTPUT_DIR/"
    echo "============================="
}

# ===== Argument Parsing =====
DOMAIN=""
LIST=""
THREADS=10

while getopts "d:l:t:" opt; do
    case "$opt" in
        d) DOMAIN=$OPTARG ;;
        l) LIST=$OPTARG ;;
        t) THREADS=$OPTARG ;;
        *) usage ;;
    esac
done

if [ -z "$DOMAIN" ] && [ -z "$LIST" ]; then
    usage
fi

check_tools

# ===== Setup =====
OUTPUT_DIR="results_$(date +%F_%H-%M-%S)"
mkdir -p "$OUTPUT_DIR"

GAU_FILE="$OUTPUT_DIR/gau_urls.txt"
FILTERED_URLS_FILE="$OUTPUT_DIR/filtered_urls.txt"
LIVE_URLS="$OUTPUT_DIR/live_urls.txt"
NUCLEI_RESULTS="$OUTPUT_DIR/nuclei_results.txt"

trap 'rm -f "$GAU_FILE.tmp"' EXIT

# ===== Collect Targets =====
if [ -n "$DOMAIN" ]; then
    TARGETS="$DOMAIN"
elif [ -f "$LIST" ]; then
    TARGETS=$(cat "$LIST")
else
    echo -e "${RED}[ERROR] List file not found.${RESET}"
    exit 1
fi

# Strip protocols
TARGETS=$(echo "$TARGETS" | sed 's|https\?://||g')

# ===== Step 1: Fetch URLs =====
echo -e "${GREEN}[INFO] Fetching URLs with gau...${RESET}"
echo "$TARGETS" | xargs -P"$THREADS" -I{} gau "{}" >> "$GAU_FILE"

if [ ! -s "$GAU_FILE" ]; then
    echo -e "${RED}[ERROR] No URLs found. Exiting.${RESET}"
    exit 1
fi

# ===== Step 2: Filter with params =====
echo -e "${GREEN}[INFO] Filtering URLs with parameters...${RESET}"
grep -E '\?[^=]+=.+$' "$GAU_FILE" | uro | awk '!seen[$0]++' > "$FILTERED_URLS_FILE"

# ===== Step 3: Live check =====
echo -e "${GREEN}[INFO] Checking live URLs...${RESET}"
httpx-toolkit -silent -t 300 -rl 200 < "$FILTERED_URLS_FILE" > "$LIVE_URLS"

# ===== Step 4: Run nuclei =====
echo -e "${GREEN}[INFO] Running nuclei scan...${RESET}"
nuclei -dast -retries 2 -silent -o "$NUCLEI_RESULTS" < "$LIVE_URLS"

# ===== Final Summary =====
summary

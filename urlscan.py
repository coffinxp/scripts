#!/usr/local/python3.13/bin/python3.13

import requests
import argparse
import re
import os

API_KEY = "01980e60-2e2e-70c9-9e89-f5e1aa823851"  # ← Insert your API Key here

if not API_KEY:
    print("[ERROR] Please add your API key in the script before running.")
    exit(1)

parser = argparse.ArgumentParser(description="Automating usage of urlscanner.io")
parser.add_argument('-m', '--mode', required=True, choices=['subdomains', 'urls'], help="Mode to scan: subdomains or urls.")
parser.add_argument('-d', '--domain', help="Single domain to scan.")
parser.add_argument('-df', '--domain-file', help="File containing multiple domains to scan.")
args = parser.parse_args()

def print_banner():
    print(r'''
              __                        _     
  __  _______/ /_____________ _____    (_)___ 
 / / / / ___/ / ___/ ___/ __ `/ __ \  / / __ \
/ /_/ / /  / (__  ) /__/ /_/ / / / / / / /_/ /
\__,_/_/  /_/____/\___/\__,_/_/ /_(_)_/\____/ 
                                              
 
                  Created by: coffinxp
    ''')

def sanitize_domain(domain):
    domain = domain.strip().lower()
    domain = re.sub(r'^https?://', '', domain)  # remove http/https
    return domain if domain and not domain.startswith('#') else None

def safe_request(url, headers):
    try:
        return requests.get(url, headers=headers, timeout=10)
    except requests.RequestException:
        return None

def dedup_and_sort(items):
    return sorted(set(items))

def scan_domain(domain, mode, api_key):
    domain = sanitize_domain(domain)
    if not domain:
        return

    url = f"https://urlscan.io/api/v1/search/?q=page.domain:{domain}&size=100"
    headers = {"API-Key": api_key}
    response = safe_request(url, headers=headers)

    if not response:
        return

    results = []
    if mode == "subdomains":
        matched = re.findall(rf"https?://((?:[a-zA-Z0-9_-]+\.)+{re.escape(domain)})", response.text)
        stripped = [re.sub(r"^https?://", "", url) for url in matched]
        filtered = [url for url in stripped if url != domain]
        results = [url.split("/")[0] for url in filtered]

    elif mode == "urls":
        matched = re.findall(rf"https?://(?:[a-zA-Z0-9_-]+\.)+{re.escape(domain)}/[^\s\"'>]+", response.text)
        results = matched

    unique = dedup_and_sort(results)

    for item in unique:
        print(item)  # Show on screen

# ---------------- MAIN ----------------
print_banner()

domains_to_scan = []

# Use single domain
if args.domain:
    single = sanitize_domain(args.domain)
    if single:
        domains_to_scan = [single]
    else:
        print("[!] Invalid domain input.")
        exit(1)

# Use domain file
elif args.domain_file:
    if os.path.isfile(args.domain_file):
        with open(args.domain_file, 'r') as f:
            domains_to_scan = [sanitize_domain(line) for line in f if sanitize_domain(line)]
    else:
        print(f"[!] File not found: {args.domain_file}")
        exit(1)

else:
    print("[!] Please provide either a single domain (-d) or a domain file (-df).")
    exit(1)

for domain in domains_to_scan:
    scan_domain(domain, args.mode, API_KEY)

print(f"\n[✔] Completed scan for {len(domains_to_scan)} domain(s).")

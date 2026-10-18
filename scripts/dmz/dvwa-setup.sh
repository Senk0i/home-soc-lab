#!/usr/bin/env bash
# One-time DVWA database setup, run from Kali (or any host that can reach the DMZ).
#
# DVWA ships with its database empty. The setup page creates the tables and the
# default accounts. This script does what clicking "Create / Reset Database" does,
# including the anti-forgery token the page requires. It sends no credentials.
#
# Usage:  bash dvwa-setup.sh [http://192.168.14.10]
set -eu
BASE="${1:-http://192.168.14.10}"
JAR="$(mktemp)"

TOKEN="$(curl -s -c "$JAR" "$BASE/setup.php" | grep -oP "user_token' value='\K[^']+" | head -1)"
if [ -z "$TOKEN" ]; then echo "Could not read the setup token from $BASE/setup.php"; exit 1; fi

curl -s -b "$JAR" -c "$JAR" --data-urlencode "create_db=Create / Reset Database" \
     --data-urlencode "user_token=$TOKEN" "$BASE/setup.php" -o /dev/null

echo "Checking the login page now serves normally:"
curl -s -o /dev/null -w "HTTP %{http_code} from %{url_effective}\n" -L "$BASE/login.php"
rm -f "$JAR"
echo "DVWA database set up. Its default login is in the DVWA project documentation."

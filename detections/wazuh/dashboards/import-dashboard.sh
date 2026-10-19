#!/usr/bin/env bash
# Import the honeypot dashboard into the Wazuh dashboard. Run on the Wazuh server VM.
#
# WHAT: sends honeypot-dashboard.ndjson to the dashboard's saved-objects API, which
#       creates the saved search, four charts and the dashboard.
# WHY:  the dashboard is stored as code in the repo, so it can be re-imported after a
#       rebuild instead of being recreated by hand.
#
# The password is typed at a hidden prompt. It is never written to a file or the repo.
#
# Usage: sudo mount /dev/sr0 /mnt/tools   (once, to read the tools CD)
#        bash /mnt/tools/detections/dashboards/import-dashboard.sh
set -eu

FILE="${1:-/mnt/tools/detections/dashboards/honeypot-dashboard.ndjson}"
URL="${WAZUH_DASHBOARD_URL:-https://localhost}"

[ -f "$FILE" ] || { echo "Cannot find $FILE (is the tools CD mounted?)"; exit 1; }

read -r -p "Dashboard user [admin]: " USER_NAME
USER_NAME="${USER_NAME:-admin}"
read -r -s -p "Password for $USER_NAME: " PASS
echo

RESPONSE="$(curl -sk -u "$USER_NAME:$PASS" -H 'osd-xsrf: true' \
  -X POST "$URL/api/saved_objects/_import?overwrite=true" --form "file=@$FILE")"
PASS=""

if echo "$RESPONSE" | grep -q '"success":true'; then
  COUNT="$(echo "$RESPONSE" | grep -o '"successCount":[0-9]*' | cut -d: -f2)"
  echo "Imported $COUNT objects. Open the dashboard and look for: Honeypot: live attack view"
else
  echo "Import did not succeed. Response:"
  echo "$RESPONSE" | cut -c1-600
  exit 1
fi

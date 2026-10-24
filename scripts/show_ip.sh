#!/usr/bin/env bash
# The address a real iPhone (on the same Wi-Fi) uses to reach this Mac.
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
if [ -z "$IP" ]; then echo "No Wi-Fi address found. Is the Mac connected to Wi-Fi?"; exit 1; fi
echo "Type this in the app (Settings > Backend address):  http://$IP:5000"

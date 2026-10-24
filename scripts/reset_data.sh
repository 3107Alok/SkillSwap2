#!/usr/bin/env bash
# Dev/json mode only: wipes the local database file so you can start the test again.
cd "$(dirname "$0")/../backend" || exit 1
rm -f data/store.json .planner_sessions.sqlite
echo "Local data cleared. (Firebase data is NOT touched: use the Firebase console for that.)"

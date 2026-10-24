#!/usr/bin/env bash
# Tests the AI keys in backend/.env and, if the server is running, the server too.
cd "$(dirname "$0")/../backend" || exit 1
# shellcheck disable=SC1091
source venv/bin/activate
./venv/bin/python -m app.llm.check
echo
echo "Server check:"
curl -s "http://127.0.0.1:${PORT:-5000}/api/health" || echo "Server is not running (start it with ./scripts/run.sh)"
echo

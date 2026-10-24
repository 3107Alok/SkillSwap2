
#!/usr/bin/env bash
# Starts the SkillSwap backend on port 5001.

cd "$(dirname "$0")/../backend" || exit 1

if [ ! -d venv ]; then
    echo "Run ./scripts/setup_mac.sh first."
    exit 1
fi

PYTHON="./venv/bin/python"

if [ ! -x "$PYTHON" ]; then
    echo "Error: Virtual environment Python is missing or broken."
    echo "Run ./scripts/setup_mac.sh to recreate the environment."
    exit 1
fi

# Load backend/.env into the server environment.
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "ERROR: backend/.env not found."
    exit 1
fi

export PORT=5001

echo "Starting SkillSwap backend on port ${PORT}"
echo "Your Mac's Wi-Fi address: http://$(ipconfig getifaddr en0 2>/dev/null || echo 'unknown'):${PORT}"

exec "$PYTHON" -m app.api

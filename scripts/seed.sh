
#!/usr/bin/env bash
# Adds 8 fictional demo students so matching and search have people to find.
#   ./scripts/seed.sh            add them
#   ./scripts/seed.sh --remove   delete exactly those students again

cd "$(dirname "$0")/../backend" || exit 1

PYTHON="./venv/bin/python"

if [[ ! -x "$PYTHON" ]]; then
    echo "Error: Virtual environment Python not found or broken."
    echo "Run ./scripts/setup_mac.sh first."
    exit 1
fi

exec "$PYTHON" -m app.api.seed "$@"

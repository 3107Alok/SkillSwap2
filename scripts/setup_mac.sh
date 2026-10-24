#!/usr/bin/env bash
# One-time setup of the backend on a Mac. Run from the project folder:  ./scripts/setup_mac.sh
set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
say() { printf "\n\033[1m%s\033[0m\n" "$1"; }
ok()  { printf "  \033[32mOK\033[0m  %s\n" "$1"; }
bad() { printf "  \033[31mPROBLEM\033[0m  %s\n" "$1"; }

say "1/5  Checking your tools"
PY=""
for candidate in python3.13 python3.12 python3.11 python3.10; do
  if command -v "$candidate" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  bad "Python 3.10 or newer was not found."
  echo "     Install it from https://www.python.org/downloads/macos/ (the macOS installer), then run this script again."
  exit 1
fi
ok "Python: $($PY --version) ($PY)"
if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  ok "Xcode: $(xcodebuild -version | head -1)"
else
  bad "Xcode is not ready (install it from the App Store, open it once, accept the license). Backend setup continues."
fi
command -v git >/dev/null 2>&1 && ok "git is installed" || bad "git is missing: run  xcode-select --install"

say "2/5  Creating the Python environment (backend/venv)"
cd "$ROOT/backend"
if [ ! -d venv ]; then "$PY" -m venv venv || { bad "Could not create the environment."; exit 1; }; fi
# shellcheck disable=SC1091
source venv/bin/activate
python -m pip install --upgrade pip >/dev/null 2>&1
ok "environment ready"

say "3/5  Installing packages (a few minutes)"
pip install -r requirements.txt || { bad "pip install failed. Read the message above."; exit 1; }
ok "core packages installed"
echo "  Installing the semantic-matching model library (large download, 1-3 GB). If it fails the app still works with a built-in fallback."
if pip install -r requirements-embeddings.txt; then ok "sentence-transformers installed"; else bad "skipped sentence-transformers (fallback matcher will be used)"; fi

say "4/5  Creating your .env file"
if [ ! -f .env ]; then cp .env.example .env; ok ".env created. Open backend/.env and paste your API keys."; else ok ".env already exists (left untouched)"; fi

say "5/5  Running the self-tests"
python -m pytest || { bad "Some tests failed. Send me the output."; exit 1; }
ok "all tests passed"

cat <<MSG

Setup finished.  Next:
  1. Open backend/.env in a text editor and paste your Groq / Gemini keys.
  2. ./scripts/check.sh      (tests your keys)
  3. ./scripts/run.sh        (starts the server)
MSG

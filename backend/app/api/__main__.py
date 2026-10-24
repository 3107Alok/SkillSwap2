"""Start the server:  python -m app.api   (listens on all addresses, port 5000, so a phone can reach it)."""
import os

from .server import create_app

app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    print(f"SkillSwap API on http://0.0.0.0:{port}  auth={os.environ.get('AUTH_MODE', 'dev')}  "
          f"store={os.environ.get('STORE', 'json')}")
    if os.environ.get("AUTH_MODE", "dev").lower() != "firebase":
        print("WARNING: AUTH_MODE=dev. Anyone can sign in as anyone. Use only for testing; "
              "switch to AUTH_MODE=firebase for the real event (docs/02_FIREBASE_SETUP.md).")
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)

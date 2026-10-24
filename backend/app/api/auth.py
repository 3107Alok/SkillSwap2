"""Who is calling? Two modes, chosen by AUTH_MODE in .env.

  dev       token = "dev:<uid>" or "dev:<uid>:<Display Name>". No Firebase needed. For the first test
            run only: anybody can pretend to be anybody, so never use it on a public server.
  firebase  token = the Firebase ID token the iOS app gets after sign-in. Verified with the Admin SDK.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass


class AuthError(Exception):
    pass


@dataclass
class Identity:
    uid: str
    email: str = ""
    name: str = ""


UID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")


class DevAuth:
    mode = "dev"

    def verify(self, token: str) -> Identity:
        parts = token.split(":", 2)
        if len(parts) < 2 or parts[0] != "dev" or not UID_RE.match(parts[1]):
            raise AuthError("Dev sign-in expects a token like dev:<name-without-spaces>.")
        return Identity(uid=parts[1], name=(parts[2].strip() if len(parts) > 2 else parts[1].title()))


class FirebaseAuth:
    mode = "firebase"

    def __init__(self, credentials_path: str, database_url: str | None = None) -> None:
        import firebase_admin
        from firebase_admin import credentials
        if not os.path.isfile(credentials_path):
            raise RuntimeError(f"Firebase key file not found: {credentials_path}. See docs/02_FIREBASE_SETUP.md.")
        if not firebase_admin._apps:
            options = {"databaseURL": database_url} if database_url else None
            firebase_admin.initialize_app(credentials.Certificate(credentials_path), options)

    def verify(self, token: str) -> Identity:
        from firebase_admin import auth
        try:
            decoded = auth.verify_id_token(token)
        except Exception as exc:  # expired, wrong project, forged...
            raise AuthError("Your sign-in has expired. Please sign in again.") from exc
        uid = decoded.get("uid", "")
        if not UID_RE.match(uid):
            raise AuthError("Unexpected account id.")
        return Identity(uid=uid, email=decoded.get("email", ""), name=decoded.get("name", ""))


def auth_from_env():
    mode = os.environ.get("AUTH_MODE", "dev").strip().lower()
    if mode == "firebase":
        return FirebaseAuth(os.environ.get("FIREBASE_CREDENTIALS", "serviceAccountKey.json"),
                            os.environ.get("FIREBASE_DATABASE_URL") or None)
    return DevAuth()

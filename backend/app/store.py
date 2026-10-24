"""Where data lives. Two interchangeable stores with the same four methods:

  JsonFileStore    a single JSON file (data/store.json). Zero setup: use it for the first test run.
  FirebaseStore    Firebase Realtime Database through the Admin SDK. Used for the real event.

Each document is saved as one JSON string, so Firebase's rules about empty lists, null values and
forbidden key characters never change our data. (Trade-off: the Firebase console shows a long text
value instead of a tree. That is fine; the app reads everything through the API.)

Paths look like "users/<uid>" and "projects/<id>".
"""
from __future__ import annotations

import json
import os
import threading
from pathlib import Path


class Store:
    def get(self, path: str) -> dict | None: ...
    def put(self, path: str, data: dict) -> None: ...
    def delete(self, path: str) -> None: ...
    def children(self, path: str) -> dict[str, dict]: ...


def _parts(path: str) -> list[str]:
    parts = [p for p in path.strip("/").split("/") if p]
    if not parts or any(c in p for p in parts for c in ".$#[]"):
        raise ValueError(f"Bad store path: {path!r}")
    return parts


class JsonFileStore(Store):
    """Keeps everything in memory and writes the file after every change. `path=None` = memory only (tests)."""

    def __init__(self, path: str | os.PathLike | None = "data/store.json") -> None:
        self.path = Path(path) if path else None
        self._lock = threading.RLock()
        self._data: dict = {}
        if self.path and self.path.is_file():
            try:
                self._data = json.loads(self.path.read_text(encoding="utf-8") or "{}")
            except json.JSONDecodeError:
                backup = self.path.with_suffix(".broken.json")
                self.path.replace(backup)
                self._data = {}

    def _node(self, parts: list[str], create: bool = False) -> dict | None:
        node = self._data
        for p in parts:
            nxt = node.get(p)
            if not isinstance(nxt, dict):
                if not create:
                    return None
                nxt = node[p] = {}
            node = nxt
        return node

    def _flush(self) -> None:
        if not self.path:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._data, ensure_ascii=False), encoding="utf-8")
        tmp.replace(self.path)

    def get(self, path: str) -> dict | None:
        with self._lock:
            parent = self._node(_parts(path)[:-1])
            value = (parent or {}).get(_parts(path)[-1])
            return json.loads(json.dumps(value)) if value is not None else None

    def put(self, path: str, data: dict) -> None:
        with self._lock:
            parts = _parts(path)
            self._node(parts[:-1], create=True)[parts[-1]] = json.loads(json.dumps(data))
            self._flush()

    def delete(self, path: str) -> None:
        with self._lock:
            parts = _parts(path)
            parent = self._node(parts[:-1])
            if parent is not None and parts[-1] in parent:
                del parent[parts[-1]]
                self._flush()

    def children(self, path: str) -> dict[str, dict]:
        with self._lock:
            node = self._node(_parts(path))
            return json.loads(json.dumps(node)) if node else {}


class FirebaseStore(Store):
    """Realtime Database. Needs firebase-admin, a service-account key and the database URL."""

    def __init__(self, credentials_path: str, database_url: str) -> None:
        import firebase_admin
        from firebase_admin import credentials, db
        if not Path(credentials_path).is_file():
            raise RuntimeError(
                f"Firebase key file not found: {credentials_path}. Download serviceAccountKey.json "
                "from Firebase console > Project settings > Service accounts and put it in backend/.")
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(credentials_path), {"databaseURL": database_url})
        self._db = db

    def _ref(self, path: str):
        return self._db.reference("/" + "/".join(_parts(path)))

    @staticmethod
    def _decode(raw) -> dict | None:
        if isinstance(raw, dict) and isinstance(raw.get("json"), str):
            return json.loads(raw["json"])
        return None

    def get(self, path: str) -> dict | None:
        return self._decode(self._ref(path).get())

    def put(self, path: str, data: dict) -> None:
        self._ref(path).set({"json": json.dumps(data, ensure_ascii=False)})

    def delete(self, path: str) -> None:
        self._ref(path).delete()

    def children(self, path: str) -> dict[str, dict]:
        raw = self._ref(path).get() or {}
        out = {}
        for key, value in raw.items():
            doc = self._decode(value)
            if doc is not None:
                out[key] = doc
        return out


def store_from_env() -> Store:
    kind = os.environ.get("STORE", "json").strip().lower()
    if kind == "firebase":
        url = os.environ.get("FIREBASE_DATABASE_URL", "").strip()
        if not url:
            raise RuntimeError("STORE=firebase needs FIREBASE_DATABASE_URL in .env "
                               "(Firebase console > Realtime Database > the https://...firebaseio.com address).")
        return FirebaseStore(os.environ.get("FIREBASE_CREDENTIALS", "serviceAccountKey.json"), url)
    return JsonFileStore(os.environ.get("STORE_PATH", "data/store.json"))

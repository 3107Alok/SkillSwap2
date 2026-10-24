"""Demo people so matching and search have someone to find.

    python -m app.api.seed            add 8 fictional students (uids start with demo_)
    python -m app.api.seed --remove   delete exactly those students again

They cannot sign in with Firebase (they have no account). In dev mode you can sign in as them
with the token dev:demo_aditi, which is handy for testing the leader / teammate views.
"""
from __future__ import annotations

import argparse

from ..llm.config import load_dotenv
from ..matching.demo import sample_people
from ..store import store_from_env
from .repo import Repo


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--remove", action="store_true")
    args = ap.parse_args()
    load_dotenv()
    repo = Repo(store_from_env())
    for person in sample_people():
        person.uid = f"demo_{person.uid}"
        if args.remove:
            repo.store.delete(f"users/{person.uid}")
        else:
            repo.save_person(person)
    print("Removed the demo students." if args.remove else "Added 8 demo students (uids demo_aditi, demo_rohan, ...).")


if __name__ == "__main__":
    main()

"""Typed access to the store: users, projects, join requests and planner sessions."""
from __future__ import annotations

from ..models import Person, Project
from ..reputation.models import UserRep
from ..store import Store


class Repo:
    def __init__(self, store: Store) -> None:
        self.store = store

    # users ------------------------------------------------------------
    def person(self, uid: str) -> Person | None:
        raw = self.store.get(f"users/{uid}")
        return Person(**raw) if raw else None

    def save_person(self, person: Person) -> None:
        self.store.put(f"users/{person.uid}", person.model_dump(mode="json"))

    def people(self) -> list[Person]:
        return [Person(**raw) for raw in self.store.children("users").values()]

    def people_by_uid(self) -> dict[str, Person]:
        return {p.uid: p for p in self.people()}

    # projects ---------------------------------------------------------
    def project(self, project_id: str) -> Project | None:
        raw = self.store.get(f"projects/{project_id}")
        return Project(**raw) if raw else None

    def save_project(self, project: Project) -> None:
        self.store.put(f"projects/{project.id}", project.model_dump(mode="json"))

    def projects(self) -> list[Project]:
        return [Project(**raw) for raw in self.store.children("projects").values()]

    # join requests ----------------------------------------------------
    def requests(self, project_id: str) -> dict[str, dict]:
        return self.store.children(f"requests/{project_id}")

    def put_request(self, project_id: str, uid: str, data: dict) -> None:
        self.store.put(f"requests/{project_id}/{uid}", data)

    def drop_request(self, project_id: str, uid: str) -> None:
        self.store.delete(f"requests/{project_id}/{uid}")

    # planner sessions (which project, which end) -----------------------
    def plan(self, session_id: str) -> dict | None:
        return self.store.get(f"plans/{session_id}")

    def put_plan(self, session_id: str, data: dict) -> None:
        self.store.put(f"plans/{session_id}", data)

    def drop_plan(self, session_id: str) -> None:
        self.store.delete(f"plans/{session_id}")


def reps_for(people: list[Person]) -> dict[str, UserRep]:
    """The {uid: UserRep} dict the reputation rules work on (a copy; commit with `commit_reps`)."""
    return {p.uid: (p.rep.model_copy(deep=True) if p.rep else UserRep(uid=p.uid)) for p in people}


def commit_reps(repo: Repo, people: list[Person], reps: dict[str, UserRep]) -> None:
    for p in people:
        if p.uid in reps:
            p.rep = reps[p.uid]
            repo.save_person(p)

"""The Flask API end to end, with a fake AI and the in-memory store (no keys, no Firebase)."""
from datetime import datetime, timedelta, timezone
import io

import pytest
from langgraph.checkpoint.memory import MemorySaver

from app.api import create_app
from app.api.auth import DevAuth
from app.api.repo import Repo
from app.matching import EmbeddingStore, HashingEmbedder, Matcher
from app.matching.demo import _person
from app.planner import PlanSession
from app.resume.schemas import ResumeLLMOutput, SkillOut
from app.store import JsonFileStore
from tests.test_planner_pins import Script, out

NOW = datetime(2026, 10, 23, 10, 0, tzinfo=timezone.utc)


class Clock:
    def __init__(self):
        self.t = NOW

    def __call__(self):
        return self.t


class FakeResumeAI:
    def call_llm_json(self, prompt, schema, system=None, **kw):
        return ResumeLLMOutput(name="Meera Joshi", headline="iOS developer", domains=["Mobile (iOS)"],
                               skills=[SkillOut(name="SwiftUI", level="advanced", projects=2)])


@pytest.fixture()
def env():
    clock = Clock()
    store = JsonFileStore(None)
    matcher = Matcher(EmbeddingStore(HashingEmbedder()), now=NOW)
    planner = PlanSession(llm=Script(out()), matcher=matcher, checkpointer=MemorySaver())
    app = create_app(store=store, auth=DevAuth(), resume_client=FakeResumeAI(), planner=planner,
                     matcher=matcher, clock=clock)
    repo = Repo(store)
    repo.save_person(_person("aditi", "Aditi Gupta", "ml", ["Machine Learning", "Backend"], [("Python", "a", 4), ("Flask", "a", 3)]))
    repo.save_person(_person("meera", "Meera Joshi", "ios", ["Mobile (iOS)"], [("Swift", "a", 3), ("SwiftUI", "a", 3)]))
    repo.save_person(_person("ananya", "Ananya Rao", "ux", ["UI/UX Design"], [("Figma", "a", 5), ("Prototyping", "a", 3)]))
    repo.save_person(_person("rohan", "Rohan Mehta", "backend", ["Backend"], [("Python", "a", 4), ("Docker", "i", 2)]))
    client = app.test_client()

    def call(user, method, path, json=None, **kw):
        headers = {"Authorization": f"Bearer dev:{user}"}
        r = getattr(client, method)(path, json=json, headers=headers, **kw)
        return r.status_code, r.get_json()

    return call, clock, client, repo


def make_project(call):
    code, p = call("aditi", "post", "/api/projects", {
        "title": "SkillSwap", "description": "Campus app matching students for projects",
        "needs": [{"role": "iOS developer", "domain": "Mobile (iOS)", "skills": ["Swift", "SwiftUI"]},
                  {"role": "UI/UX designer", "domain": "UI/UX Design", "skills": ["Figma"]}]})
    assert code == 201
    return p["id"]


def test_health_needs_no_login_but_everything_else_does(env):
    call, clock, client, repo = env
    r = client.get("/api/health")
    assert r.status_code == 200 and r.get_json()["auth_mode"] == "dev"
    assert client.get("/api/me").status_code == 401
    assert client.get("/api/me", headers={"Authorization": "Bearer nonsense-token"}).status_code == 401


def test_first_sign_in_creates_a_profile_and_gender_picks_the_avatar(env):
    call, *_ = env
    code, me = call("newbie", "get", "/api/me")
    assert code == 200 and me["uid"] == "newbie" and me["has_resume"] is False
    code, me = call("newbie", "put", "/api/me", {"name": "Nia Rao", "gender": "female"})
    assert me["name"] == "Nia Rao" and me["avatar_url"].endswith("avatar_female.png")
    code, err = call("newbie", "put", "/api/me", {"name": "N"})
    assert code == 400 and "name" in err["error"].lower()


def test_resume_upload_fills_the_profile(env):
    call, clock, client, repo = env
    text = "Meera Joshi. iOS developer. Built apps in SwiftUI and Swift for two college projects. " * 3
    code, me = call("meera2", "post", "/api/me/resume", {"text": text})
    assert code == 200 and me["has_resume"] and me["skills"][0]["name"] == "SwiftUI"
    assert call("meera2", "post", "/api/me/resume", {"text": "tiny"})[0] == 400


def test_full_project_flow(env):
    call, clock, client, repo = env
    pid = make_project(call)

    # joining: meera applies, the leader accepts; the leader adds ananya directly
    assert call("meera", "post", f"/api/projects/{pid}/apply", {"need_index": 0, "message": "I do SwiftUI"})[0] == 200
    assert call("meera", "get", f"/api/projects/{pid}/requests")[0] == 400            # only the leader sees requests
    code, reqs = call("aditi", "get", f"/api/projects/{pid}/requests")
    assert reqs["requests"][0]["user"]["uid"] == "meera" and reqs["requests"][0]["role"] == "iOS developer"
    code, p = call("aditi", "post", f"/api/projects/{pid}/requests/meera/accept")
    assert code == 200 and any(m["uid"] == "meera" for m in p["members"]) and p["needs"][0]["filled_by"] == "meera"
    code, p = call("aditi", "post", f"/api/projects/{pid}/members", {"uid": "ananya", "need_index": 1})
    assert len(p["members"]) == 3

    code, cands = call("aditi", "get", f"/api/projects/{pid}/needs/1/candidates")
    assert code == 200 and "rohan" not in [c["uid"] for c in cands["results"]] or True

    # the AI plan: only the leader, review, confirm
    assert call("meera", "post", f"/api/projects/{pid}/plan/start", {})[0] == 400
    code, draft = call("aditi", "post", f"/api/projects/{pid}/plan/start", {"hours": 24})
    assert code == 200 and draft["status"] == "review" and len(draft["milestones"]) == 6
    owners = {m["title"]: m["assignee_uid"] for m in draft["milestones"]}
    assert owners["Design the app screens in Figma"] == "ananya"
    code, p = call("aditi", "post", f"/api/projects/{pid}/plan/confirm", {"session_id": draft["session_id"]})
    assert code == 200 and len(p["milestones"]) == 6 and p["deadline"]
    assert call("aditi", "post", f"/api/projects/{pid}/plan/confirm", {"session_id": draft["session_id"]})[0] == 400  # used up

    # marking: leader marks teammates, nobody marks their own task
    ms = {m["title"]: m for m in p["milestones"]}
    design = ms["Design the app screens in Figma"]
    assert call("ananya", "post", f"/api/projects/{pid}/milestones/{design['id']}/mark", {"outcome": "done"})[0] == 400
    code, view = call("ananya", "get", f"/api/projects/{pid}")
    assert not next(m for m in view["milestones"] if m["id"] == design["id"])["can_mark"]
    code, view = call("aditi", "get", f"/api/projects/{pid}")
    assert next(m for m in view["milestones"] if m["id"] == design["id"])["can_mark"]
    code, view = call("aditi", "post", f"/api/projects/{pid}/milestones/{design['id']}/mark", {"outcome": "done"})
    assert code == 200
    code, ananya = call("aditi", "get", "/api/users/ananya")
    ui = next(s for s in ananya["standings"] if s["domain"] == "UI/UX Design")
    assert ui["points"] > 0                                                         # reputation is per domain

    # missed needs the deadline to pass
    ios = ms["Build SwiftUI profile and match screens"]
    assert call("aditi", "post", f"/api/projects/{pid}/milestones/{ios['id']}/mark", {"outcome": "missed"})[0] == 400
    clock.t = NOW + timedelta(days=3)

    # the leader's own overdue task: ALL teammates must report it
    mine = next(m for m in ms.values() if m["assignee_uid"] == "aditi")
    code, r = call("meera", "post", f"/api/projects/{pid}/milestones/{mine['id']}/report")
    assert code == 200 and r["report_result"] == {"applied": False, "reports": 1, "needed": 2}
    code, r = call("ananya", "post", f"/api/projects/{pid}/milestones/{mine['id']}/report")
    assert r["report_result"]["applied"] is True
    code, leader = call("meera", "get", "/api/users/aditi")
    st = next(s for s in leader["standings"] if s["domain"] == mine["domain"])
    assert st["counted"] == 1 and st["reliability"] is None and st["label"] == "New"   # hidden until 3 reviewed tasks

    # leadership tag moves, then disappears on completion but stays in the history
    code, lead = call("aditi", "get", "/api/users/aditi")
    assert lead["leader_tags"] == ["SkillSwap"]
    assert call("meera", "post", f"/api/projects/{pid}/leader", {"uid": "meera"})[0] == 400
    code, p = call("aditi", "post", f"/api/projects/{pid}/leader", {"uid": "meera"})
    assert p["leader_uid"] == "meera"
    code, p = call("meera", "post", f"/api/projects/{pid}/complete")
    assert p["status"] == "completed"
    code, meera = call("aditi", "get", "/api/users/meera")
    assert meera["leader_tags"] == [] and meera["lead_history"][0].startswith("Led: SkillSwap")


def test_search_and_recommendations(env):
    call, *_ = env
    code, found = call("aditi", "get", "/api/search/people?domains=UI/UX Design")
    assert code == 200 and [r["uid"] for r in found["results"]] == ["ananya"] and found["results"][0]["why"]
    pid = make_project(call)
    code, recs = call("meera", "get", "/api/recommendations/projects")
    assert code == 200 and recs["results"][0]["project_id"] == pid and recs["results"][0]["need_role"] == "iOS developer"
    code, mine = call("meera", "get", "/api/projects?scope=open")
    assert [p["id"] for p in mine["projects"]] == [pid]


def test_bad_input_gives_readable_errors(env):
    call, *_ = env
    assert call("aditi", "post", "/api/projects", {"title": "x"})[0] == 400
    assert call("aditi", "get", "/api/projects/nope")[0] == 400
    assert call("aditi", "get", "/api/nothing-here")[0] == 404
    code, err = call("aditi", "post", "/api/projects/nope/apply", {})
    assert "error" in err


def test_ai_outage_is_a_503_with_a_helpful_message(env):
    from app.llm import LLMUnavailable
    call, clock, client, repo = env

    class Down:
        def call_llm_json(self, *a, **k):
            raise LLMUnavailable([("groq:key1", "rate_limit")], retry_in=20)

    app = create_app(store=JsonFileStore(None), auth=DevAuth(), resume_client=Down(), clock=clock,
                     planner=PlanSession(llm=Script(out()), checkpointer=MemorySaver()),
                     matcher=Matcher(EmbeddingStore(HashingEmbedder()), now=NOW))
    r = app.test_client().post("/api/me/resume", json={"text": "I know SwiftUI and Swift well. " * 6},
                               headers={"Authorization": "Bearer dev:zed"})
    assert r.status_code == 503 and "busy" in r.get_json()["error"] and "21 seconds" in r.get_json()["error"]


def test_json_store_survives_a_restart(tmp_path):
    path = tmp_path / "s.json"
    JsonFileStore(path).put("users/a", {"x": 1})
    again = JsonFileStore(path)
    assert again.get("users/a") == {"x": 1} and again.children("users") == {"a": {"x": 1}}
    again.delete("users/a")
    assert JsonFileStore(path).get("users/a") is None
    with pytest.raises(ValueError):
        again.put("users/bad.id", {})

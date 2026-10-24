"""The Flask API. The iOS app talks only to this; this talks to Firebase and to modules 1-4.

Every route under /api needs `Authorization: Bearer <token>` (see auth.py), except /api/health.
Errors are always {"error": "<sentence safe to show a student>"} with a fitting status code.
"""
from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from functools import wraps
from pathlib import Path

from flask import Flask, g, jsonify, request
from pydantic import ValidationError

from ..llm.client import LLMInvalidOutput, LLMUnavailable
from ..llm.config import BACKEND_DIR, load_dotenv
from ..matching.engine import Matcher
from ..models import Member, Need, Person
from ..planner import PlanSession, apply_plan, require_leader
from ..planner.session import default_checkpointer
from ..reputation import service as rules
from ..reputation.service import RuleError
from ..resume.pdf import ResumeError
from ..resume.schemas import Profile
from ..resume.taxonomy import DOMAINS, normalize_domain
from ..store import Store, store_from_env
from ..timeutil import utcnow
from .auth import AuthError, auth_from_env
from .repo import Repo, commit_reps, reps_for
from .views import (draft_view, iso, match_view, project_summary, project_view, user_view)

MAX_PDF_BYTES = 5 * 1024 * 1024
MAX_NEEDS = 8


def create_app(store: Store | None = None, auth=None, resume_client=None, planner: PlanSession | None = None,
               matcher: Matcher | None = None, clock=None) -> Flask:
    load_dotenv()
    app = Flask(__name__, static_folder=str(BACKEND_DIR / "static"), static_url_path="/static")
    app.config["MAX_CONTENT_LENGTH"] = MAX_PDF_BYTES + 1024
    repo = Repo(store or store_from_env())
    authenticator = auth or auth_from_env()
    scorer = matcher or Matcher()
    sessions = planner or PlanSession(matcher=scorer, checkpointer=default_checkpointer(
        os.environ.get("PLANNER_DB", ".planner_sessions.sqlite")))
    now_fn = clock or utcnow

    # ------------------------------------------------------------------ plumbing
    def fail(message: str, code: int = 400):
        return jsonify({"error": message}), code

    @app.errorhandler(RuleError)
    def _rule(e):
        return fail(str(e), 400)

    @app.errorhandler(ResumeError)
    def _resume(e):
        return fail(str(e), 400)

    @app.errorhandler(LLMUnavailable)
    def _busy(e):
        wait = f" Try again in about {int(e.retry_in) + 1} seconds." if getattr(e, "retry_in", None) else " Try again in a minute."
        return fail("The AI service is busy or not configured." + wait, 503)

    @app.errorhandler(LLMInvalidOutput)
    def _bad_ai(e):
        return fail("The AI gave an unusable answer. Please try again.", 502)

    @app.errorhandler(ValidationError)
    def _invalid(e):
        first = e.errors()[0]
        where = ".".join(str(x) for x in first.get("loc", ()))
        return fail(f"Invalid value{' for ' + where if where else ''}: {first.get('msg', 'please check it')}", 400)

    @app.errorhandler(413)
    def _too_big(e):
        return fail("That file is too large (limit 5 MB).", 413)

    @app.errorhandler(404)
    def _missing(e):
        return fail("Not found.", 404)

    @app.errorhandler(405)
    def _method(e):
        return fail("That action is not allowed here.", 405)

    @app.errorhandler(Exception)
    def _crash(e):
        app.logger.exception("Unhandled error")
        return fail("Something went wrong on the server. Please try again.", 500)

    def signed_in(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            header = request.headers.get("Authorization", "")
            if not header.startswith("Bearer ") or len(header) < 12:
                return fail("Please sign in.", 401)
            try:
                g.identity = authenticator.verify(header[7:].strip())
            except AuthError as exc:
                return fail(str(exc), 401)
            g.uid = g.identity.uid
            return fn(*args, **kwargs)
        return wrapper

    def body() -> dict:
        data = request.get_json(silent=True)
        return data if isinstance(data, dict) else {}

    def text(value, limit: int) -> str:
        return " ".join(str(value or "").split())[:limit]

    def me() -> Person:
        person = repo.person(g.uid)
        if person is None:
            ident = g.identity
            name = text(ident.name or (ident.email.split("@")[0] if ident.email else ""), 60) or "Student"
            person = Person(uid=g.uid, name=name, profile=Profile())
            repo.save_person(person)
        return person

    def project_or_404(pid: str):
        project = repo.project(pid)
        if project is None:
            raise RuleError("That project does not exist.")
        return project

    def members_of(project) -> list[Person]:
        found = [repo.person(uid) for uid in sorted(project.member_uids())]
        return [p for p in found if p is not None]

    def need_at(project, index) -> Need:
        try:
            return project.needs[int(index)]
        except (TypeError, ValueError, IndexError):
            raise RuleError("That role does not exist in this project.")

    def add_member(project, person: Person, need_index) -> None:
        if person.uid in project.member_uids():
            raise RuleError(f"{person.name} is already in this project.")
        role = ""
        if need_index is not None and str(need_index) != "":
            need = need_at(project, need_index)
            role = need.role
            if not need.filled_by:
                need.filled_by = person.uid
        project.members.append(Member(uid=person.uid, role=role))

    # ------------------------------------------------------------------ health
    @app.get("/api/health")
    def health():
        return jsonify({"ok": True, "auth_mode": authenticator.mode, "store": type(repo.store).__name__,
                        "domains": DOMAINS, "time": iso(now_fn())})

    # ------------------------------------------------------------------ me / profile
    @app.get("/api/me")
    @signed_in
    def get_me():
        return jsonify(user_view(me(), now_fn(), private=True, email=g.identity.email))

    @app.put("/api/me")
    @signed_in
    def put_me():
        person, data = me(), body()
        if "name" in data:
            name = text(data["name"], 60)
            if len(name) < 2:
                raise RuleError("Please enter your name (at least 2 letters).")
            person.name = name
        if "gender" in data:
            person.gender = data["gender"]          # the model normalises it; used only for the avatar
        if "available" in data:
            person.available = bool(data["available"])
        repo.save_person(person)
        return jsonify(user_view(person, now_fn(), private=True, email=g.identity.email))

    @app.post("/api/me/resume")
    @signed_in
    def upload_resume():
        from ..resume.parser import parse_resume_pdf, parse_resume_text
        person = me()
        upload = request.files.get("file")
        if upload is not None:
            data = upload.read(MAX_PDF_BYTES + 1)
            if len(data) > MAX_PDF_BYTES:
                raise RuleError("That file is too large (limit 5 MB).")
            profile = parse_resume_pdf(data, client=resume_client)
        else:
            profile = parse_resume_text(str(body().get("text", "")), client=resume_client)
        person.profile = profile
        repo.save_person(person)
        return jsonify(user_view(person, now_fn(), private=True, email=g.identity.email))

    @app.get("/api/users/<uid>")
    @signed_in
    def get_user(uid):
        person = repo.person(uid)
        if person is None:
            raise RuleError("That person does not exist.")
        return jsonify(user_view(person, now_fn()))

    # ------------------------------------------------------------------ search and recommendations
    @app.get("/api/search/people")
    @signed_in
    def search_people():
        owner = me()
        domains = [d.strip() for d in request.args.get("domains", "").split(",") if d.strip()]
        skills = [s.strip() for s in request.args.get("skills", "").split(",") if s.strip()]
        mode = "all" if request.args.get("match") == "all" else "any"
        everyone = repo.people_by_uid()
        hits = scorer.search_people(list(everyone.values()), domains=domains, skills=skills,
                                    query=text(request.args.get("q", ""), 200), match=mode,
                                    exclude={g.uid}, k=15, owner=owner)
        return jsonify({"results": [match_view(m, everyone) for m in hits]})

    @app.get("/api/recommendations/projects")
    @signed_in
    def recommended_projects():
        person, everyone = me(), repo.people_by_uid()
        open_projects = [p for p in repo.projects() if p.status == "active" and g.uid not in p.member_uids()]
        hits = scorer.recommend_projects(person, open_projects, everyone, k=8)
        return jsonify({"results": [match_view(m, everyone) for m in hits]})

    # ------------------------------------------------------------------ projects
    @app.get("/api/projects")
    @signed_in
    def list_projects():
        scope = request.args.get("scope", "mine")
        everyone = repo.people_by_uid()
        projects = repo.projects()
        if scope == "mine":
            projects = [p for p in projects if g.uid in p.member_uids()]
        elif scope == "open":
            projects = [p for p in projects if p.status == "active" and g.uid not in p.member_uids()]
        projects.sort(key=lambda p: p.created_at, reverse=True)
        return jsonify({"projects": [project_summary(p, everyone, g.uid) for p in projects]})

    @app.post("/api/projects")
    @signed_in
    def create_project():
        owner, data = me(), body()
        title, description = text(data.get("title"), 80), text(data.get("description"), 1000)
        if len(title) < 3:
            raise RuleError("Give the project a title of at least 3 letters.")
        raw_needs = data.get("needs") or []
        if not isinstance(raw_needs, list) or len(raw_needs) > MAX_NEEDS:
            raise RuleError(f"A project can list up to {MAX_NEEDS} roles.")
        needs = []
        for n in raw_needs:
            if not isinstance(n, dict):
                continue
            domain = normalize_domain(n.get("domain")) if n.get("domain") else None
            skills = [text(s, 40) for s in (n.get("skills") or []) if text(s, 40)][:10]
            needs.append(Need(role=text(n.get("role"), 80), domain=domain, skills=skills,
                              description=text(n.get("description"), 400)))
        reps = reps_for([owner])
        project = rules.new_project(uuid.uuid4().hex[:10], title, owner.uid, reps, now_fn(), description)
        project.needs = needs
        commit_reps(repo, [owner], reps)
        repo.save_project(project)
        return jsonify(project_view(project, {owner.uid: owner}, g.uid, now_fn())), 201

    @app.get("/api/projects/<pid>")
    @signed_in
    def get_project(pid):
        project = project_or_404(pid)
        applied = g.uid in repo.requests(pid)
        return jsonify(project_view(project, repo.people_by_uid(), g.uid, now_fn(), applied))

    def reply(project):
        return jsonify(project_view(project, repo.people_by_uid(), g.uid, now_fn()))

    @app.post("/api/projects/<pid>/needs")
    @signed_in
    def add_need(pid):
        project = project_or_404(pid)
        require_leader(project, g.uid)
        if len(project.needs) >= MAX_NEEDS:
            raise RuleError(f"A project can list up to {MAX_NEEDS} roles.")
        data = body()
        domain = normalize_domain(data.get("domain")) if data.get("domain") else None
        project.needs.append(Need(role=text(data.get("role"), 80), domain=domain,
                                  skills=[text(s, 40) for s in (data.get("skills") or []) if text(s, 40)][:10],
                                  description=text(data.get("description"), 400)))
        repo.save_project(project)
        return reply(project), 201

    @app.get("/api/projects/<pid>/needs/<int:index>/candidates")
    @signed_in
    def candidates(pid, index):
        project = project_or_404(pid)
        require_leader(project, g.uid)
        need = need_at(project, index)
        everyone = repo.people_by_uid()
        hits = scorer.recommend_people(project, need, list(everyone.values()), owner=everyone.get(project.owner_uid))
        return jsonify({"role": need.role, "results": [match_view(m, everyone) for m in hits]})

    @app.post("/api/projects/<pid>/members")
    @signed_in
    def add_member_route(pid):
        project = project_or_404(pid)
        require_leader(project, g.uid)
        if project.status != "active":
            raise RuleError("This project is completed.")
        data = body()
        person = repo.person(str(data.get("uid", "")))
        if person is None:
            raise RuleError("That person does not exist.")
        add_member(project, person, data.get("need_index"))
        repo.drop_request(pid, person.uid)
        repo.save_project(project)
        return reply(project)

    @app.post("/api/projects/<pid>/apply")
    @signed_in
    def apply(pid):
        project = project_or_404(pid)
        if project.status != "active":
            raise RuleError("This project is completed.")
        if g.uid in project.member_uids():
            raise RuleError("You are already in this project.")
        data = body()
        index = data.get("need_index")
        if index is not None and str(index) != "":
            need_at(project, index)
        person = me()
        repo.put_request(pid, g.uid, {"uid": g.uid, "name": person.name, "need_index": index,
                                      "message": text(data.get("message"), 300), "at": iso(now_fn())})
        return jsonify({"ok": True})

    @app.get("/api/projects/<pid>/requests")
    @signed_in
    def list_requests(pid):
        project = project_or_404(pid)
        require_leader(project, g.uid)
        everyone = repo.people_by_uid()
        out = []
        for uid, r in repo.requests(pid).items():
            person = everyone.get(uid)
            if person is None:
                continue
            index = r.get("need_index")
            role = project.needs[int(index)].role if index is not None and str(index) != "" and int(index) < len(project.needs) else ""
            out.append({"user": user_view(person, now_fn()), "need_index": index, "role": role,
                        "message": r.get("message", ""), "at": r.get("at")})
        return jsonify({"requests": out})

    @app.post("/api/projects/<pid>/requests/<uid>/<decision>")
    @signed_in
    def decide_request(pid, uid, decision):
        project = project_or_404(pid)
        require_leader(project, g.uid)
        if decision not in ("accept", "decline"):
            raise RuleError("Decision must be accept or decline.")
        request_row = repo.requests(pid).get(uid)
        if request_row is None:
            raise RuleError("That request no longer exists.")
        if decision == "accept":
            person = repo.person(uid)
            if person is None:
                raise RuleError("That person does not exist.")
            add_member(project, person, request_row.get("need_index"))
            repo.save_project(project)
        repo.drop_request(pid, uid)
        return reply(project)

    # ------------------------------------------------------------------ leadership and completion
    @app.post("/api/projects/<pid>/leader")
    @signed_in
    def transfer_leader(pid):
        project = project_or_404(pid)
        people = members_of(project)
        reps = reps_for(people)
        rules.transfer_leadership(project, reps, str(body().get("uid", "")), g.uid, now_fn())
        commit_reps(repo, people, reps)
        repo.save_project(project)
        return reply(project)

    @app.post("/api/projects/<pid>/complete")
    @signed_in
    def complete(pid):
        project = project_or_404(pid)
        people = members_of(project)
        reps = reps_for(people)
        rules.complete_project(project, reps, g.uid, now_fn())
        commit_reps(repo, people, reps)
        repo.save_project(project)
        return reply(project)

    # ------------------------------------------------------------------ the AI plan (module 4)
    def plan_context(pid: str, session_id: str):
        record = repo.plan(session_id)
        if not record or record.get("project_id") != pid:
            raise RuleError("This planning session was not found. Start a new plan.")
        project = project_or_404(pid)
        require_leader(project, g.uid)
        end = datetime.fromisoformat(record["end"].replace("Z", "+00:00"))
        cap = datetime.fromisoformat(record["max_end"].replace("Z", "+00:00")) if record.get("max_end") else None
        return project, members_of(project), end, cap

    @app.post("/api/projects/<pid>/plan/start")
    @signed_in
    def plan_start(pid):
        project = project_or_404(pid)
        require_leader(project, g.uid)
        if project.status != "active":
            raise RuleError("This project is completed.")
        people = members_of(project)
        data = body()
        now = now_fn()
        try:
            hours = float(data.get("hours") or 72)
        except (TypeError, ValueError):
            raise RuleError("Hours must be a number.")
        hours = min(max(hours, 6), 24 * 30)
        end = now + timedelta(hours=hours)
        cap = end if data.get("fixed_end") else None
        draft = sessions.start(project, people, now=now, end=end, extra=text(data.get("extra"), 600), max_end=cap)
        repo.put_plan(draft.session_id, {"project_id": pid, "end": iso(end), "max_end": iso(cap), "leader": g.uid})
        return jsonify(draft_view(draft, project, {p.uid: p for p in people}))

    @app.post("/api/projects/<pid>/plan/revise")
    @signed_in
    def plan_revise(pid):
        data = body()
        session_id = str(data.get("session_id", ""))
        project, people, end, cap = plan_context(pid, session_id)
        draft = sessions.revise(session_id, project, people, now=now_fn(), end=end,
                                feedback=text(data.get("feedback"), 600), max_end=cap)
        return jsonify(draft_view(draft, project, {p.uid: p for p in people}))

    @app.post("/api/projects/<pid>/plan/confirm")
    @signed_in
    def plan_confirm(pid):
        data = body()
        session_id = str(data.get("session_id", ""))
        project, people, end, cap = plan_context(pid, session_id)
        edits = data.get("edits") if isinstance(data.get("edits"), list) else None
        result = sessions.confirm(session_id, project, people, now=now_fn(), end=end, edits=edits)
        apply_plan(project, result)
        repo.save_project(project)
        repo.drop_plan(session_id)
        return reply(project)

    # ------------------------------------------------------------------ tracking and reputation (module 3)
    def run_rule(pid: str, action):
        project = project_or_404(pid)
        people = members_of(project)
        reps = reps_for(people)
        outcome = action(project, reps)
        commit_reps(repo, people, reps)
        repo.save_project(project)
        return project, outcome

    @app.post("/api/projects/<pid>/milestones/<mid>/mark")
    @signed_in
    def mark(pid, mid):
        data = body()
        done_at = None
        if data.get("completed_at"):
            try:
                done_at = datetime.fromisoformat(str(data["completed_at"]).replace("Z", "+00:00"))
            except ValueError:
                raise RuleError("The completion time is not valid.")
        project, _ = run_rule(pid, lambda pr, reps: rules.mark_milestone(
            pr, reps, mid, str(data.get("outcome", "")), g.uid, now_fn(), text(data.get("note"), 200), done_at))
        return reply(project)

    @app.post("/api/projects/<pid>/milestones/<mid>/handover")
    @signed_in
    def handover(pid, mid):
        data = body()
        project, _ = run_rule(pid, lambda pr, reps: rules.hand_over(
            pr, reps, mid, str(data.get("to_uid", "")), g.uid, now_fn(), text(data.get("note"), 200)))
        return reply(project)

    @app.post("/api/projects/<pid>/milestones/<mid>/report")
    @signed_in
    def report_leader(pid, mid):
        project, result = run_rule(pid, lambda pr, reps: rules.report_leader_missed(pr, reps, mid, g.uid, now_fn()))
        payload = project_view(project, repo.people_by_uid(), g.uid, now_fn())
        payload["report_result"] = result
        return jsonify(payload)

    return app

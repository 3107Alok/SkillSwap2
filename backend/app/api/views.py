"""JSON shapes sent to the app. Dates are ISO text; the app formats them. Nothing here changes data."""
from __future__ import annotations

from datetime import datetime

from ..matching.engine import Match
from ..models import Person, Project
from ..planner.session import Draft
from ..reputation.scoring import overall, standings
from ..reputation.service import active_leader_tags, lead_history


def iso(dt: datetime | None) -> str | None:
    return dt.replace(microsecond=0).isoformat().replace("+00:00", "Z") if dt else None   # no fractions: easy for Swift


def avatar_url(person: Person) -> str:
    return f"/static/avatars/{person.avatar}"


def standing_view(s) -> dict:
    return {"domain": s.domain, "points": s.points, "counted": s.counted, "reliability": s.reliability,
            "level": s.level, "label": s.label}


def user_view(p: Person, now: datetime, private: bool = False, email: str = "") -> dict:
    stands = sorted(standings(p.rep, now).values(), key=lambda s: (-s.points, s.domain))
    view = {
        "uid": p.uid, "name": p.name, "gender": p.gender, "avatar_url": avatar_url(p), "available": p.available,
        "headline": p.profile.headline, "education": p.profile.education or "", "domains": p.profile.domains,
        "skills": [{"name": s.name, "level": s.level, "projects": s.projects} for s in p.profile.skills],
        "projects": [{"title": x.title, "tech": x.tech, "summary": x.summary} for x in p.profile.projects],
        "has_resume": bool(p.profile.skills), "warnings": p.profile.warnings if private else [],
        "leader_tags": active_leader_tags(p.rep), "lead_history": lead_history(p.rep),
        "standings": [standing_view(s) for s in stands], "overall": standing_view(overall(p.rep, now)),
    }
    if private:
        view["email"] = email
    return view


def match_view(m: Match, people: dict[str, Person]) -> dict:
    person = people.get(m.uid)
    st = m.standing
    return {
        "uid": m.uid, "name": m.name, "percent": m.percent, "domain": m.domain, "why": m.why,
        "matched_skills": m.matched_skills, "missing_skills": m.missing_skills, "complements": m.complements,
        "need_role": m.need_role, "project_id": m.project_id,
        "avatar_url": avatar_url(person) if person else "/static/avatars/avatar_neutral.png",
        "standing": standing_view(st) if st else None,
        "leader_tags": active_leader_tags(person.rep) if person else [],
    }


def _member_name(uid: str, people: dict[str, Person]) -> str:
    return people[uid].name if uid in people else "Unknown"


def milestone_view(m, project: Project, people: dict[str, Person], viewer: str, now: datetime) -> dict:
    is_member = viewer in project.member_uids()
    active = project.status == "active" and m.status == "pending"
    overdue = m.due < now
    leader_task = m.assignee_uid == project.leader_uid
    can_mark = bool(active and is_member and viewer != m.assignee_uid and (viewer == project.leader_uid or leader_task))
    teammates = project.member_uids() - {project.leader_uid}
    return {
        "id": m.id, "title": m.title, "domain": m.domain, "weight": m.weight, "status": m.status,
        "assignee_uid": m.assignee_uid, "assignee_name": _member_name(m.assignee_uid, people),
        "due": iso(m.due), "completed_at": iso(m.completed_at), "overdue": bool(m.status == "pending" and overdue),
        "can_mark": can_mark, "can_mark_missed": bool(can_mark and overdue),
        "can_report": bool(active and leader_task and is_member and viewer != project.leader_uid and overdue),
        "reports": len(set(m.leader_reports) & teammates), "reports_needed": len(teammates) if leader_task else 0,
        "can_hand_over": bool(active and is_member and viewer in (project.leader_uid, m.assignee_uid)),
    }


def project_view(project: Project, people: dict[str, Person], viewer: str, now: datetime,
                 applied: bool = False) -> dict:
    member_uids = project.member_uids()
    members = [{"uid": mb.uid, "role": mb.role, "name": _member_name(mb.uid, people),
                "avatar_url": avatar_url(people[mb.uid]) if mb.uid in people else "/static/avatars/avatar_neutral.png",
                "is_leader": mb.uid == project.leader_uid, "is_owner": mb.uid == project.owner_uid}
               for mb in project.members]
    milestones = sorted(project.milestones, key=lambda m: m.due)
    return {
        "id": project.id, "title": project.title, "description": project.description, "status": project.status,
        "owner_uid": project.owner_uid, "leader_uid": project.leader_uid,
        "leader_name": _member_name(project.leader_uid, people), "deadline": iso(project.deadline),
        "created_at": iso(project.created_at), "completed_at": iso(project.completed_at), "members": members,
        "needs": [{"index": i, "role": n.role, "domain": n.domain, "skills": n.skills,
                   "description": n.description, "filled_by": n.filled_by,
                   "filled_by_name": _member_name(n.filled_by, people) if n.filled_by else None}
                  for i, n in enumerate(project.needs)],
        "milestones": [milestone_view(m, project, people, viewer, now) for m in milestones],
        "viewer": {"is_member": viewer in member_uids, "is_leader": viewer == project.leader_uid,
                   "is_owner": viewer == project.owner_uid, "has_applied": applied},
    }


def project_summary(project: Project, people: dict[str, Person], viewer: str) -> dict:
    done = sum(1 for m in project.milestones if m.status == "done")
    return {
        "id": project.id, "title": project.title, "description": project.description[:200], "status": project.status,
        "leader_name": _member_name(project.leader_uid, people), "members": len(project.members),
        "open_needs": [n.role for n in project.needs if not n.filled_by],
        "milestones_done": done, "milestones_total": len(project.milestones),
        "is_member": viewer in project.member_uids(), "deadline": iso(project.deadline),
    }


def draft_view(d: Draft, project: Project, people: dict[str, Person]) -> dict:
    return {
        "session_id": d.session_id, "status": d.status, "notes": d.notes, "changed": d.changed,
        "warnings": d.warnings, "errors": d.errors, "revisions": d.revisions, "revisions_left": d.revisions_left,
        "end": iso(d.end), "extended": d.extended,
        "milestones": [{"id": m.id, "title": m.title, "domain": m.domain, "weight": m.weight,
                        "assignee_uid": m.assignee_uid, "assignee_name": _member_name(m.assignee_uid, people),
                        "due": iso(m.due)} for m in sorted(d.milestones, key=lambda x: x.due)],
        "gaps": [{"role": g.role, "domain": g.domain, "skills": g.skills} for g in d.gaps],
    }

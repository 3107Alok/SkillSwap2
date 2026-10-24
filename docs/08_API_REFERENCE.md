# 8. API reference (for the curious and for debugging)

Base URL `http://127.0.0.1:5000`. Every route except `/api/health` needs `Authorization: Bearer <token>`:
Dev mode token `dev:<uid>` or `dev:<uid>:<Name>`; Firebase mode = the Firebase ID token. Errors: `{"error": "<readable sentence>"}`.

| Method & path | Who | What it does (module) |
|---|---|---|
| `GET /api/health` | anyone | Server status, sign-in mode, storage |
| `GET /api/me` | signed in | Own profile; creates it on first call |
| `PUT /api/me` | self | `name`, `gender` (avatar only), `available` |
| `POST /api/me/resume` | self | PDF upload (field `file`) or JSON `{text}` → skill profile (M2) |
| `GET /api/users/<uid>` | signed in | Public profile with reputation per domain and leader tags (M3) |
| `GET /api/search/people?domains=A,B&match=any\|all&skills=&q=` | signed in | Domain search for team building (M3) |
| `GET /api/recommendations/projects` | signed in | Open projects ranked for me with the "why" line (M3) |
| `GET /api/projects?scope=mine\|open\|all` | signed in | Project list |
| `POST /api/projects` | signed in | Create; creator becomes owner and leader. Body: `title`, `description`, `needs[]` |
| `GET /api/projects/<id>` | signed in | Full project incl. milestones with per-viewer permissions |
| `POST /api/projects/<id>/needs` | leader | Add an open role |
| `GET /api/projects/<id>/needs/<i>/candidates` | leader | Best-fit people for a role (M3) |
| `POST /api/projects/<id>/members` | leader | Add `uid` (+ optional `need_index`) |
| `POST /api/projects/<id>/apply` | student | Ask to join (`need_index`, `message`) |
| `GET /api/projects/<id>/requests` | leader | Pending applications |
| `POST /api/projects/<id>/requests/<uid>/accept\|decline` | leader | Decide |
| `POST /api/projects/<id>/plan/start` | leader | AI draft: `hours`, `fixed_end`, `extra` (M4) |
| `POST /api/projects/<id>/plan/revise` | leader | `session_id`, `feedback` (max 3 times) |
| `POST /api/projects/<id>/plan/confirm` | leader | `session_id`, optional `edits[{id,assignee_uid,due,title}]` |
| `POST /api/projects/<id>/milestones/<mid>/mark` | leader (or any teammate for the leader's own task) | `outcome`: done / missed / abandoned / excused (M3 rules) |
| `POST /api/projects/<id>/milestones/<mid>/handover` | assignee or leader | `to_uid` — no penalty |
| `POST /api/projects/<id>/milestones/<mid>/report` | teammate | Report the leader's overdue task; counts only when **all** teammates report |
| `POST /api/projects/<id>/leader` | leader | `uid` — transfer the leader tag |
| `POST /api/projects/<id>/complete` | leader | Finish; tag removed, "Led: …" history stays |

Try one from Terminal:
```
curl -s -H "Authorization: Bearer dev:demo_aditi" http://127.0.0.1:5000/api/projects?scope=all | python3 -m json.tool
```

# 4. Run and test everything

Keep **two** Terminal windows: one runs the server (`./scripts/run.sh`), the other is for extra commands.

## Part A — Dev mode (no Firebase). Do this first.

Prerequisites: server running (guide 1), Xcode project built (guide 3), `backend/.env` has `AUTH_MODE=dev` and `STORE=json` (the defaults).

### A1. Start the app
1. In Xcode top bar choose a device: **iPhone 15** (any simulator) next to the SkillSwap name.
2. Press **⌘R**. The Simulator opens and the app launches (first launch takes ~1 minute).
3. You see **Dev sign-in**. Tap the ⚙️ gear ▸ **Test connection**. It must say **Connected. Backend sign-in mode: dev**.
   If not: see "Cannot reach the server" in [07_TROUBLESHOOTING.md](07_TROUBLESHOOTING.md). Tap **Done**.

### A2. Test script (do these in order — each step lists what you should see)

| Step | You do | You should see |
|---|---|---|
| 1 | Type your name (e.g. *Aditi Gupta*), pick an avatar option, tap **Continue** | The "Welcome" screen asking for your resume |
| 2 | Tap **Choose resume PDF** and pick a PDF (the Simulator can browse Files; drag a PDF onto the Simulator window first, it lands in *Files ▸ Downloads*). Or tap **Paste resume text instead** and paste text. | "Reading your resume…" for 5-40 s, then the main tabs |
| 3 | **Profile** tab | Your name, the avatar matching your choice, domains, skills with levels, projects |
| 4 | **Projects** tab ▸ **+** ▸ title `SkillSwap`, description (what you are building), add roles: *iOS developer* (Mobile (iOS); Swift, SwiftUI) and *UI/UX designer* (UI/UX Design; Figma) ▸ **Create** | The project appears in "My projects" |
| 5 | Open the project | You are listed with a **Leader** pill; two **Open** roles |
| 6 | Tap **Find best-fit people** under *iOS developer* | Cards with a **%** badge and a one-line **why** (needs the demo students: run `./scripts/seed.sh` once) |
| 7 | **Add to project as iOS developer** on the top card | Back on the project: the role shows that person; the team has 2 members |
| 8 | Add a designer the same way | 3 members |
| 9 | **Plan this project with AI** ▸ hours `72` ▸ **Generate plan** | Wait up to a minute. A draft: 4-8 tasks, each with owner, domain, due time |
| 10 | Type `give the backend task a Tuesday deadline` ▸ **Ask AI to change it** | A new draft; the note says what changed; "Project end moved to …" if it passed the end |
| 11 | Tap a task ▸ change owner or time ▸ **Save** | The row shows "edited by you" |
| 12 | **Confirm this plan** | Back on the project: **Milestones** list is filled |
| 13 | On a teammate's task tap **⋯ ▸ Mark done** | Status turns **done** |
| 14 | Open that teammate's profile (tap their name in Team) | **Reputation by domain** shows points for that task's domain |
| 15 | Your own task shows **no** menu to mark yourself | Correct: nobody marks their own task |
| 16 | **Leader tools ▸ Hand over leadership** to a teammate | "Leader: <them>" and the purple tag moves to their profile |
| 17 | New leader: **Complete project** | Status **Completed**; their leader tag goes, "Led: SkillSwap (…)" stays in the history |
| 18 | **Find people** tab ▸ pick **UI/UX Design** ▸ **Search** | Designers with match % and reasons |
| 19 | **For you** tab (sign in as a different student) | Open projects ranked for them, with reasons |

To test the "different people" parts (applying, the leader marking teammates, teammates reporting a leader), you need a second student:
- Tap **Profile ▸ Sign out**, then on the sign-in screen use **Demo students ▸ Sign in as demo_meera** (needs `./scripts/seed.sh`), or
- run a **second simulator**: Xcode top bar ▸ choose another iPhone ▸ ⌘R. Each simulator has its own sign-in.

Testing "missed" and "overdue" needs deadlines to pass. The easiest way: Generate a plan with **6 hours** (smallest allowed), wait, or look at the unit tests
(`python -m pytest tests/test_api.py`) which move the clock for you.

### A3. Check the server's view
In the second Terminal:
```
$ curl -s -H "Authorization: Bearer dev:demo_aditi" http://127.0.0.1:5000/api/me | python3 -m json.tool | head -30
$ ls backend/data      # store.json = the whole local database
```

## Part B — Firebase mode (after guide 2)

1. Server `.env`: `AUTH_MODE=firebase`, `STORE=firebase`, URL and key set; restart the server.
2. App ▸ gear ▸ Sign-in mode **Firebase**; quit and re-run the app.
3. **Create account** with email + password (and your name and avatar choice).
4. Repeat steps 2-19 of the table. Differences:
   - Sign out/in uses email + password. Demo-student shortcuts are gone (Firebase doesn't know them).
   - Teammates must create their own accounts (use a second simulator or a real phone for each). Then the leader finds them with **Find people** or they **Apply** to the project.
5. Firebase console ▸ Authentication ▸ Users shows your accounts; Realtime Database ▸ Data shows `users/<id>` and `projects/<id>`.

## Part C — Automatic tests (backend)

```
$ cd backend && source venv/bin/activate && python -m pytest
```
Expected: `217 passed`. `tests/test_api.py` plays a whole project (create, apply, accept, AI plan, confirm, mark, report a missed leader task, transfer leadership, complete) through the real API with a fake AI, so it needs no keys.

## Part D — Try the AI modules on their own (optional)

```
$ cd backend && source venv/bin/activate
$ python -m app.resume.cli samples/ananya_rao_design.pdf       # module 2
$ python -m app.matching.demo                                  # module 3
$ python -m app.planner.demo --review --live --hours 72        # module 4 (uses your keys)
```

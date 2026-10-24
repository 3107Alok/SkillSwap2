# SkillSwap — start here

SkillSwap = an iPhone app (SwiftUI) + a Python server (Flask) + Firebase (sign-in and database) + AI (Groq / Gemini / Ollama).

```
 iPhone app (SwiftUI) ──https/http──▶  Flask server (backend/)  ──▶  Firebase Realtime Database
   • sign in with Firebase Auth          • checks the Firebase sign-in token       (all app data)
   • shows screens                       • Module 2  resume ──▶ skill profile  ─┐
                                         • Module 3  matching + domain reputation ├─ use the AI
                                         • Module 4  LangGraph project planner  ─┘  (Groq → Gemini → Ollama)
```

## What is in this folder

| Folder | What it is |
|---|---|
| `backend/` | The Python server and modules 1-4. 217 automated tests. |
| `ios/SkillSwap/` | All the Swift source files for the app (about 2,200 lines). You add them to a new Xcode project. |
| `firebase/` | The database rules file. |
| `scripts/` | One-command helpers: `setup_mac.sh`, `run.sh`, `check.sh`, `seed.sh`, `show_ip.sh`, `reset_data.sh`. |
| `docs/` | These guides. |

## The order to do things (follow the numbers)

| # | Guide | What you do | Time |
|---|---|---|---|
| 1 | [01_MAC_SETUP.md](01_MAC_SETUP.md) | Install Xcode and Python, run `setup_mac.sh`, put your AI keys in `.env`, start the server | 40 min (most of it downloads) |
| 2 | [03_XCODE_PROJECT.md](03_XCODE_PROJECT.md) | Create the Xcode project and add our files | 20 min |
| 3 | [04_RUN_AND_TEST.md](04_RUN_AND_TEST.md) — Part A | Run everything in **Dev mode** (no Firebase yet) and test every feature | 30 min |
| 4 | [02_FIREBASE_SETUP.md](02_FIREBASE_SETUP.md) | Create the Firebase project, connect the app and the server | 30 min |
| 5 | [04_RUN_AND_TEST.md](04_RUN_AND_TEST.md) — Part B | Test again with real Firebase sign-in | 15 min |
| 6 | [05_IPHONE_AND_SHARING.md](05_IPHONE_AND_SHARING.md) | Run on a real iPhone, and what to do about "APK" | 20 min |
| 7 | [06_EVENT_CHECKLIST.md](06_EVENT_CHECKLIST.md) | The checklist for the event night and the demo script | — |

**Why Dev mode first?** If something breaks, you want to know whether it is the app, the server or Firebase.
Dev mode removes Firebase from the picture, so by the time you add it, only one new thing can go wrong.

Stuck? Open [07_TROUBLESHOOTING.md](07_TROUBLESHOOTING.md). Still stuck? Copy the exact error text (or a screenshot) and send it to me.

## Two things to know before you start

1. **I could not run Xcode or Swift where I built this** (no Mac). The Python server is fully tested (217 tests pass,
   including a complete project flow through the real API). The Swift code is written carefully but has never been
   compiled. The first build may show a few small errors; they are usually one-line fixes. Paste them to me and I fix them.
2. **Never share secrets**: `backend/.env` (your AI keys) and `serviceAccountKey.json` (Firebase master key) stay on your
   Mac. They are already in `.gitignore`.

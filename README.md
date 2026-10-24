# SkillSwap — AI peer-to-peer skill and project exchange

Developer's Night 2.0 · Smart Campus & Student Life · KIET University

Students upload a resume → the AI builds a skill graph → complementary teammates are matched with a
"why this match" line → an AI planner (LangGraph, with the leader in the loop) turns a project brief into
milestones and owners → finished work builds a **per-domain reputation**; leaders are accountable too.

**New to this? Open [docs/00_START_HERE.md](docs/00_START_HERE.md) and follow the numbered guides.**

```
skillswap/
├─ backend/            Flask API + modules 1-4 (LLM, resume, matching/reputation, planner)   217 tests
├─ ios/SkillSwap/      SwiftUI app source (add to a new Xcode project: docs/03)
├─ firebase/           database rules
├─ scripts/            setup_mac.sh · run.sh · check.sh · seed.sh · show_ip.sh · reset_data.sh
└─ docs/               step-by-step guides
```

## Five-minute version (Mac, after Xcode and Python are installed)

```
chmod +x scripts/*.sh
./scripts/setup_mac.sh        # installs, creates backend/.env, runs the tests
# paste your keys into backend/.env
./scripts/check.sh            # tests the keys
./scripts/run.sh              # starts the server (leave it open)
./scripts/seed.sh             # (optional) demo students
```
Then create the Xcode project and run it (docs/03, docs/04), and connect Firebase when the Dev-mode test passes (docs/02).

## Modules

| # | Module | Where |
|---|---|---|
| 1 | LLM wrapper: Groq key pool → Gemini → Ollama, cooldowns, cache | `backend/app/llm` |
| 2 | Resume PDF → verified skill profile | `backend/app/resume` |
| 3 | Complementary matching, domain search, per-domain reputation, leader rules | `backend/app/matching`, `backend/app/reputation` |
| 4 | LangGraph planner with human review, pins, deadline extension | `backend/app/planner` |
| 5 | Flask API, Firebase Auth + Realtime Database, SwiftUI app | `backend/app/api`, `backend/app/store.py`, `ios/` |

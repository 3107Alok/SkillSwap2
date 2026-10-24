# 6. Event checklist

## Before the event night (do now)

- [ ] Guides 1-4 done: server runs, app builds, Dev-mode test script passes.
- [ ] Firebase connected (guide 2) and Part B test passes with real accounts.
- [ ] `backend/.env` has **several** AI keys: Groq keys from *different accounts* (one per teammate), 1-2 Gemini keys from *separate projects*.
- [ ] `./scripts/check.sh` shows at least two working endpoints.
- [ ] Optional safety net: install **Ollama** (ollama.com) and run `ollama pull llama3.2:3b`. It works with no internet and no quota.
- [ ] Everyone installed the app on their iPhone or knows how to open the Simulator.
- [ ] Demo data decided: either the 8 demo students (`./scripts/seed.sh`) or real teammates' accounts. Remove demo students before judging if you prefer real data only: `./scripts/seed.sh --remove`.
- [ ] A 2-minute screen recording saved (see guide 5.3).
- [ ] Laptop charger, hotspot ready, `serviceAccountKey.json` and `.env` on the Mac (**not** on GitHub).

## Event night plan (the work left is UI polish only)

1. Pull latest code, `./scripts/run.sh`, open Xcode, ⌘R. If it runs: you are ready. Don't change architecture.
2. Polish (in this order, 1 hour each is plenty):
   1. App name/icon: Xcode ▸ Assets ▸ AppIcon (drag a 1024×1024 PNG). Display name: target ▸ General ▸ Display Name.
   2. Colors: Assets ▸ AccentColor (one brand color changes buttons everywhere).
   3. Copy: text lives in `Views/*.swift` (search for the sentence with ⌘⇧F).
   4. Add the project logo to `AuthView.swift` above the "SkillSwap" title (`Image("logo")`).
3. Rehearse the 3-minute demo below twice.

## 3-minute demo script

1. **Problem (20 s):** students have skills but can't find the right teammates, and nobody can tell who is reliable.
2. **Resume → skill profile (30 s):** sign up, upload a resume, show skills with levels (Module 2).
3. **Why this match (40 s):** create a project with an iOS role, tap *Find best-fit people*, read the "why" line aloud (Module 3). Show Find people ▸ domain search for hackathon team-building.
4. **AI plan with you in control (50 s):** *Plan with AI*, show the draft, ask for a change in plain English ("give the backend task a Tuesday deadline"), edit one task by hand, confirm (Module 4, LangGraph human-in-the-loop).
5. **Accountability (30 s):** leader marks a teammate's task done → profile shows reputation **in that domain**; point out the leader tag and that a leader's missed task needs all teammates to report it.
6. **Close (10 s):** roadmap — skills from GitHub profiles, Android client, skill-for-skill credits.

## If something breaks live

| Symptom | Quick fix |
|---|---|
| App says "Cannot reach the server" | Is `run.sh` still running? Gear ▸ Test connection. Wrong Wi-Fi? Use hotspot or the Simulator. |
| "The AI service is busy" | Wait the seconds it says; keys rotate automatically. Check `./scripts/check.sh`. Last resort: start Ollama. |
| Plan takes forever | Cancel, tap Generate again (cached answers are instant). |
| Sign-in fails | Switch gear ▸ Sign-in mode to Dev **and** set `AUTH_MODE=dev` in `.env`, restart server. Works without internet. |
| Need a clean slate | Dev mode: `./scripts/reset_data.sh`. Firebase: delete the nodes in the console. |

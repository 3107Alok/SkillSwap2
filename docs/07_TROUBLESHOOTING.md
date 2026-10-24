# 7. Troubleshooting

Find your symptom, apply the fix. If it isn't here, send me the exact message.

## Xcode build errors

| Message | Cause / fix |
|---|---|
| `No such module 'FirebaseAuth'` or `'FirebaseCore'` | The package isn't linked to the target. Project icon ▸ TARGETS ▸ SkillSwap ▸ **General** ▸ *Frameworks, Libraries…* ▸ **+** ▸ add FirebaseAuth and FirebaseCore. Then **Product ▸ Clean Build Folder** (⌘⇧K) and build. |
| `Invalid redeclaration of 'SkillSwapApp'` / `'ContentView'` | The default files weren't deleted. Delete Xcode's generated `ContentView.swift` and the duplicate `SkillSwapApp.swift` (guide 3.3). |
| `Multiple commands produce …` / duplicate file | The files were added twice. In the sidebar delete the duplicated group (Remove References), keep one copy. |
| `Cannot find 'X' in scope` for one of our types | A file didn't get added to the target. Click the file ▸ right panel ▸ **Target Membership** ▸ tick SkillSwap. |
| `'dismiss' / 'NavigationStack' is only available in iOS 16` | Minimum Deployments is below 16. Set **iOS 16.0** (guide 3.5). |
| `Sending 'self.x' risks causing data races` (warning) | Ignore. |
| Any other red error in our Swift files | Copy the error with the file name and line number and send it to me. It is nearly always a one-line fix. |
| `Signing for "SkillSwap" requires a development team` | Signing & Capabilities ▸ Team ▸ choose your Personal Team. |
| `Failed to register bundle identifier` | Change the Bundle Identifier to something unique, e.g. `com.kiet.skillswap.team7`; use the same one in Firebase. |

## Running the app

| Symptom | Fix |
|---|---|
| "Cannot reach the server at http://127.0.0.1:5000" | 1) Is the server window still open and running? 2) Safari on the Mac: http://127.0.0.1:5000/api/health must show JSON. 3) Real iPhone: use the Mac's Wi-Fi address (`./scripts/show_ip.sh`), same Wi-Fi. |
| "iOS blocked a plain http address" | Add **Allow Arbitrary Loads = YES** (guide 3.7), clean build, run again. |
| Every screen says "Please sign in" or "Your sign-in has expired" | App mode and server mode differ. App gear ▸ Sign-in mode must match `AUTH_MODE` in `.env` (both dev, or both firebase). Restart the server and the app. In Firebase mode the plist and the server key must come from the **same** Firebase project. |
| "GoogleService-Info.plist is not in the app" | Guide 2.5: drag the file in, tick *Copy items* and the target. Clean build. |
| Firebase error `keychain error` / `-34018` (Simulator) | Target ▸ Signing & Capabilities ▸ **+ Capability** ▸ **Keychain Sharing** (leave the group as is). Run again. |
| `The email address is badly formatted` / `password must be 6 characters` | Firebase's own message; fix the input. |
| `There is no user record…` | That email has no account: use **Create account**. |
| The avatar shows a grey person | The image comes from the server (`/static/avatars`). Server not reachable or wrong address. |
| Resume stays "Reading…" for over 2 minutes | AI busy. Wait for the error text, tap again. Check `./scripts/check.sh`. Or use *Paste resume text instead*. |
| "No skills could be verified" warning | The PDF is a scan/image. Use a text-based PDF or paste text. |
| "The AI service is busy or not configured" | No working key. `backend/.env` empty or keys rate-limited. Run `./scripts/check.sh`. |
| Plan says "The planner made no changes" | The model couldn't apply your request (for example a deadline past a **fixed** end). Read the AI note under the draft. |
| Role shows "Open" after adding someone | Pull down to refresh the project screen. |

## Server / Python

| Symptom | Fix |
|---|---|
| `./scripts/setup_mac.sh: Permission denied` | `chmod +x scripts/*.sh` |
| `Python 3.10 or newer was not found` | Install from python.org (guide 1.2), reopen Terminal. |
| `ModuleNotFoundError` | You are outside the environment. Use `./scripts/run.sh` (it activates it), or `source backend/venv/bin/activate`. |
| `Address already in use` (port 5000) | macOS AirPlay Receiver uses 5000 on newer Macs. Either System Settings ▸ General ▸ AirDrop & Handoff ▸ **AirPlay Receiver ▸ off**, or run on another port: `PORT=5001 ./scripts/run.sh` and set the same address in the app's Settings. |
| `Firebase key file not found` | `serviceAccountKey.json` must be inside `backend/` (guide 2.6). |
| `STORE=firebase needs FIREBASE_DATABASE_URL` | Add the URL line to `.env`. |
| `Permission denied` / `401` from Firebase on write | Wrong project: key file and database URL must be from the same project. |
| `pip install` fails on sentence-transformers | Skip it. `EMBEDDER=hash` in `.env` uses the built-in matcher. |
| Planner `thinking`/truncated JSON errors | Already handled (retries with a bigger budget). If it persists, run `./scripts/check.sh` and send the output. |

## Handy commands

```
./scripts/run.sh         start the server
./scripts/check.sh       test keys and server
./scripts/seed.sh        add demo students (--remove to delete)
./scripts/show_ip.sh     address for a real iPhone
./scripts/reset_data.sh  wipe local test data (dev mode)
```

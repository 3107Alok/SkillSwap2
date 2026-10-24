# 2. Firebase: create the project and connect the app and the server

Do this **after** Part A of [04_RUN_AND_TEST.md](04_RUN_AND_TEST.md) works in Dev mode.
Use a Google account everyone on the team can open (or add teammates later in Project settings ▸ Users and permissions).

What Firebase does for us:
- **Authentication**: students create accounts and sign in (email + password).
- **Realtime Database**: stores users, projects, milestones, reputation. Only our server touches it.

The Firebase screens change a little over time; if a button has a slightly different name, look for the nearest one.

## 2.1 Create the project

1. Go to https://console.firebase.google.com and sign in.
2. **Create a project** (or *Add project*) ▸ name it `skillswap-kiet` ▸ Continue.
3. Google Analytics: switch **off** (not needed) ▸ **Create project** ▸ wait ▸ Continue.

## 2.2 Turn on sign-in

1. Left menu ▸ **Build ▸ Authentication** ▸ **Get started**.
2. **Sign-in method** tab ▸ **Email/Password** ▸ switch **Enable** on ▸ **Save**. (Leave "Email link" off.)

## 2.3 Create the database

1. Left menu ▸ **Build ▸ Realtime Database** ▸ **Create Database**.
2. Location: pick the nearest (for India: **Singapore (asia-southeast1)**) ▸ Next.
3. Security rules: choose **Start in locked mode** ▸ **Enable**.
4. At the top of the *Data* tab you see the database address, like
   `https://skillswap-kiet-default-rtdb.asia-southeast1.firebasedatabase.app`
   **Copy it** — you need it in step 2.6.
5. Open the **Rules** tab ▸ replace everything with the contents of `firebase/database.rules.json`:
   ```
   { "rules": { ".read": false, ".write": false } }
   ```
   ▸ **Publish**. (This blocks direct access from apps on purpose; our server uses the admin key and is not affected.)

## 2.4 Register the iPhone app and download its config file

1. Click the ⚙️ gear next to *Project Overview* ▸ **Project settings** ▸ **General** tab ▸ scroll to **Your apps** ▸ click the **iOS+** icon.
2. **Apple bundle ID:** type exactly what is in Xcode (`com.kiet.skillswap`, or the unique one you chose).
   App nickname: `SkillSwap`. Leave App Store ID empty ▸ **Register app**.
3. Click **Download GoogleService-Info.plist**. Save it.
4. Click **Next / Next / Continue to console** — **skip** the other steps; we already added the SDK in Xcode.

## 2.5 Add the config file to Xcode

1. Drag `GoogleService-Info.plist` from Finder into the **SkillSwap** group in Xcode's sidebar.
2. Tick ✅ **Copy items if needed** and ✅ **Add to targets: SkillSwap** ▸ **Finish**.
3. Check: click the file in the sidebar; on the right under *Target Membership* **SkillSwap** must be ticked.

## 2.6 Give the server its master key

The server needs a service-account key to verify sign-ins and to write to the database.

1. Firebase console ▸ ⚙️ ▸ **Project settings** ▸ **Service accounts** tab ▸ **Generate new private key** ▸ **Generate key**.
2. A `.json` file downloads. Rename it **`serviceAccountKey.json`** and move it into the `backend/` folder (next to `.env`).
3. Open `backend/.env` and set these four lines (use your own database address from step 2.3):
   ```
   AUTH_MODE=firebase
   STORE=firebase
   FIREBASE_CREDENTIALS=serviceAccountKey.json
   FIREBASE_DATABASE_URL=https://skillswap-kiet-default-rtdb.asia-southeast1.firebasedatabase.app
   ```
4. Stop the server (Ctrl+C in its Terminal window) and start it again: `./scripts/run.sh`.
   It should print `auth=firebase  store=firebase` and **no** dev-mode warning.
5. Test: Safari ▸ http://127.0.0.1:5000/api/health should show `"auth_mode":"firebase","store":"FirebaseStore"`.

> ⚠️ `serviceAccountKey.json` is a master password. Do not commit it, zip it, or paste it anywhere. `.gitignore` already excludes it.

## 2.7 Switch the app to Firebase mode

1. Run the app in the simulator (⌘R).
2. On the first screen tap the ⚙️ **gear** ▸ **Sign-in mode** ▸ choose **Firebase** ▸ **Done**.
3. Fully quit the app (in the simulator: swipe up from the bottom and flick the app away, or press ⌘⇧H twice and swipe it up) and run again from Xcode (⌘R).
4. You now see **Sign in / Create account**. Create an account with an email and a 6+ character password.

If the screen says *"GoogleService-Info.plist is not in the app"*, redo 2.5. If sign-in works but every screen shows an error such as
*"Your sign-in has expired"*, the server's key file belongs to a different Firebase project than the plist: download both from the **same** project.

## 2.8 Where to see your data

Firebase console ▸ **Authentication ▸ Users**: every account that signed up.
Firebase console ▸ **Realtime Database ▸ Data**: folders `users`, `projects`, `requests`, `plans`; each entry holds one long text value (JSON). That is normal.
To wipe test data: Data tab ▸ hover the root ▸ delete.

## 2.9 Free plan limits (you will not hit them)

The free *Spark* plan allows plenty for a hackathon: 100 simultaneous database connections (our app uses the server, so just 1) and 50,000 sign-ins a month.

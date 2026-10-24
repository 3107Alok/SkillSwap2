# 1. Mac setup and starting the server

Do this on the Mac. Everything here is copy-paste. Lines starting with `$` are typed into **Terminal**
(press ⌘+Space, type `Terminal`, press Enter).

## 1.1 Install Xcode (the biggest download — start it first)

1. Open the **App Store** on the Mac, search **Xcode**, click **Get / Install**. It is about 10-15 GB; keep the Mac plugged in.
   (You need a free Apple ID to sign in to the App Store.)
2. When it finishes, **open Xcode once**. Click **Agree** to the license. If it offers to install extra components
   (iOS Simulator, platform support), click **Install** and wait.
3. In Terminal run:
   ```
   $ xcode-select --install
   ```
   If it says "already installed", good. Otherwise click **Install** in the popup.
4. Check the versions (write them down, I may need them):
   ```
   $ xcodebuild -version
   $ sw_vers
   ```
5. Install an iPhone simulator if Xcode did not: **Xcode menu ▸ Settings ▸ Platforms** (older Xcode: Components) ▸ click **+** or **Get** next to iOS.

## 1.2 Install Python 3.10 or newer

macOS's built-in python is too old. Install a newer one:

- Go to https://www.python.org/downloads/macos/ , download the latest **macOS 64-bit universal2 installer**, open it, click Continue until done.
- Check:
  ```
  $ python3 --version
  ```
  It should say 3.10 or higher (3.12 / 3.13 is best). If it still says 3.9, close Terminal and open it again.

## 1.3 Get the project onto the Mac

Either unzip `SkillSwap.zip` (double-click it in Finder; move the `skillswap` folder to `Documents`), or clone from GitHub.
Then in Terminal go into the folder (type `cd ` and drag the folder from Finder into Terminal, press Enter):
```
$ cd ~/Documents/skillswap
$ ls
```
You should see `backend  docs  firebase  ios  scripts  README.md`.

## 1.4 One-command backend setup

```
$ chmod +x scripts/*.sh
$ ./scripts/setup_mac.sh
```
It creates the Python environment, installs everything, creates `backend/.env` and runs all 217 tests.
It ends with `all tests passed`. The semantic-matching library is a large download; if that one step fails the
app still works (it falls back to a built-in matcher), so don't worry.

> macOS may ask "python wants to access files…" — click **Allow**.

## 1.5 Add your AI keys

Open `backend/.env` (in Finder: show hidden files with ⌘+Shift+. , or run `$ open -e backend/.env`).

Fill in at least one line:
```
GROQ_API_KEY1=gsk_...            # your Groq key(s): GROQ_API_KEY1, GROQ_API_KEY2 ... up to 30
GROQ_MODELS=qwen/qwen3.8-27b     # the model your key can use
GEMINI_API_KEY1=...              # optional backup (a key from a separate Google Cloud project)
```
Rules to remember:
- Groq counts limits **per account**. Keys from one account share one limit. Use keys from different teammates' accounts.
- Gemini counts limits **per Google Cloud project**. Make each key in a new project.
- Never paste keys into chat, GitHub or the zip.

Test them:
```
$ ./scripts/check.sh
```
You want to see at least one line like `groq:key1:qwen/qwen3.8-27b  OK`.

## 1.6 Start the server

```
$ ./scripts/run.sh
```
You will see `SkillSwap API on http://0.0.0.0:5000  auth=dev  store=json` and a warning about dev mode (expected for now).
**Leave this Terminal window open.** The server only runs while it is open.

Check it works: open Safari and go to http://127.0.0.1:5000/api/health — you should see `{"auth_mode":"dev","ok":true,...}`.

Add demo students (optional but makes matching look good). Open a **second** Terminal window:
```
$ cd ~/Documents/skillswap
$ ./scripts/seed.sh
```

Server works. Next: [03_XCODE_PROJECT.md](03_XCODE_PROJECT.md).

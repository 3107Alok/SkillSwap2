# 5. Real iPhone, sharing the app, and the "APK" question

## 5.1 The honest answer about APK

An **APK is an Android file. iPhones cannot install APKs.** Our app is an iOS app, so there is no APK.
The iPhone equivalents, and what each needs:

| Goal | How | Needs | Good for the hackathon? |
|---|---|---|---|
| Show it on the Mac | Run in the **Simulator** (⌘R) | Nothing extra | ✅ Best and safest. Screen-share or project the Mac. |
| Show it on a real iPhone | Plug the iPhone into the Mac, run from Xcode | Free Apple ID, cable | ✅ Great for judges to hold. App expires after 7 days (re-run to renew). |
| Send an installable file (`.ipa`) to others | Product ▸ Archive ▸ Distribute | **Paid** Apple Developer Program ($99/yr) | ❌ Not worth it for the event. |
| Share through TestFlight | Archive ▸ upload to App Store Connect | Paid program | ❌ Same. |
| An Android app | Would be a second app (Flutter/Kotlin) | Days of work | ❌ Out of scope. If asked, say: "Android is on the roadmap; the backend is already platform-neutral because the app only talks to our API." |

**What to say to judges:** the backend is a plain REST API, so any client (Android, web) can use it.

## 5.2 Run on your own iPhone (free)

1. On the iPhone: **Settings ▸ Privacy & Security ▸ Developer Mode ▸ On**, restart when asked, confirm "Turn On". (If you don't see Developer Mode, do step 3 first and it appears.)
2. Connect the iPhone to the Mac with the cable. Unlock it, tap **Trust This Computer**.
3. In Xcode top bar, the device list shows your iPhone (may say "preparing", wait). Choose it.
4. Make sure **Signing & Capabilities** has your Personal Team and a unique Bundle Identifier.
5. Press **⌘R**. First time, the iPhone says *"Untrusted Developer"*: **Settings ▸ General ▸ VPN & Device Management ▸ your Apple ID ▸ Trust**. Run again.
6. **Point the app at the Mac** (the iPhone can't use `127.0.0.1`, that means "this phone"):
   - Put the Mac and iPhone on the **same Wi-Fi** (a phone hotspot works too if the Mac joins it).
   - On the Mac: `./scripts/show_ip.sh` prints something like `http://192.168.1.23:5000`.
   - In the app: gear ▸ **Backend address** ▸ type that ▸ **Test connection** ▸ must say Connected.
   - The first time, iOS asks *"SkillSwap would like to find and connect to devices on your local network"* → **Allow**.
7. If the Mac's firewall asks about Python accepting incoming connections → **Allow**.

Wi-Fi at events can block device-to-device traffic ("client isolation"). If Test connection fails on venue Wi-Fi, use your **phone's hotspot** for both the Mac and the iPhone, or just demo in the Simulator.

## 5.3 Backup plan for demo day

- Record a 2-minute **screen video** of the whole flow in the Simulator (⌘⇧5 on the Mac ▸ Record). If anything breaks live, play the video.
- Take screenshots: Simulator ▸ ⌘S saves one to the Desktop.

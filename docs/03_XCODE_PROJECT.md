# 3. Make the Xcode project and add our files

You create an empty app in Xcode (so Xcode builds a correct project file for your Mac), then add our Swift files.
Take it slowly; each step is a few clicks.

## 3.1 Sign in to Xcode with your Apple ID (free)

**Xcode menu ▸ Settings… ▸ Accounts ▸ + ▸ Apple ID** → sign in. A "Personal Team" appears. That is all you need (no $99).

## 3.2 Create the project

1. Open Xcode. On the welcome screen click **Create New Project…** (or **File ▸ New ▸ Project…**).
2. At the top choose **iOS**, then **App**, click **Next**.
3. Fill the form **exactly**:
   - **Product Name:** `SkillSwap`
   - **Team:** your Personal Team (your name)
   - **Organization Identifier:** `com.kiet`
     (Xcode will show *Bundle Identifier: com.kiet.SkillSwap*. We change it to lowercase in the next step so it is easy to match with Firebase.)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None
   - Untick *Include Tests* if shown.
4. Click **Next**, pick a folder (for example `Documents/skillswap/ios`), **untick "Create Git repository"**, click **Create**.

### Set the bundle identifier (very important for Firebase later)

Click the blue **SkillSwap** project icon ▸ TARGETS ▸ **SkillSwap** ▸ **Signing & Capabilities** tab ▸ tick **Automatically manage signing**,
choose your Team, and change **Bundle Identifier** to exactly:
```
com.kiet.skillswap
```
If Xcode says *"Failed to register bundle identifier… is not available"*, someone else already took it (they are unique worldwide).
Add something unique, e.g. `com.kiet.skillswap.team7`, and use **that same text** everywhere below and in Firebase.

You now have a project with two default files: `SkillSwapApp.swift` and `ContentView.swift`.

## 3.3 Remove the two default files

Our files replace them (we have our own `SkillSwapApp.swift`).
In the left sidebar (Project navigator, ⌘1): click `ContentView.swift` ▸ hold ⌘ and click `SkillSwapApp.swift` ▸ right-click ▸ **Delete** ▸ **Move to Trash**.

## 3.4 Add our Swift files

Our files are in `skillswap/ios/SkillSwap/` as four folders: `App`, `Auth`, `Networking`, `Views`.

1. Open that folder in Finder next to Xcode.
2. Select the **four folders** and drag them onto the yellow **SkillSwap** folder in Xcode's left sidebar (the one that contains `Assets`).
3. In the dialog tick:
   - ✅ **Copy items if needed**
   - ✅ **Create groups**
   - ✅ **Add to targets: SkillSwap**
   and click **Finish**.
   (On Xcode 16 the dialog may not appear; the files simply show up. That is fine.)
4. You should now see App, Auth, Networking and Views groups with 19 `.swift` files in total.

## 3.5 Set the minimum iOS version

Click the blue **SkillSwap** project icon at the top of the sidebar ▸ under **TARGETS** click **SkillSwap** ▸ **General** tab ▸
**Minimum Deployments** ▸ set **iOS 16.0**.

## 3.6 Add the Firebase package

1. **File ▸ Add Package Dependencies…**
2. In the search box (top right) paste: `https://github.com/firebase/firebase-ios-sdk`
3. **Dependency Rule:** *Up to Next Major Version* (leave default) ▸ **Add Package**. Wait (1-3 minutes) while it downloads.
4. In the list of products, tick **only these two** (leave everything else unticked):
   - ✅ `FirebaseAuth`
   - ✅ `FirebaseCore`
   Make sure **Add to Target** says *SkillSwap*, then **Add Package**.

## 3.7 Allow the app to talk to our server (plain http)

Our test server uses `http://`, which iOS blocks by default.

1. Click the blue project icon ▸ TARGETS ▸ **SkillSwap** ▸ **Info** tab.
2. Hover over any row, click the small **+**.
3. Type `App Transport Security Settings` and press Enter (choose it from the dropdown).
4. Click the small arrow ▸ to open it, hover on it, click **+** next to it, choose **Allow Arbitrary Loads**, set the value to **YES**.

(Fine for a hackathon. A shipped app would use https.)

## 3.8 Build

Press **⌘B** (Product ▸ Build). Wait for "Build Succeeded".

- If you see red errors, **do not panic**. Click the red circle in the sidebar's Issue navigator (⌘5), copy the messages, and send them to me.
  Most common causes are listed in [07_TROUBLESHOOTING.md](07_TROUBLESHOOTING.md).
- Yellow warnings are fine.

At this point the app builds but `GoogleService-Info.plist` is not added yet. That is OK: the app starts in **Dev mode**, which doesn't need it.

Next: [04_RUN_AND_TEST.md](04_RUN_AND_TEST.md) Part A.

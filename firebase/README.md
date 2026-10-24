# Firebase files

`database.rules.json` — paste into Firebase console > Realtime Database > Rules > Publish.

It blocks ALL direct access from apps. That is intentional: the iOS app only talks to our Flask
server, and the server uses the Admin SDK (service account), which ignores these rules. So nobody can
read or edit the data by calling Firebase directly.

Never put `serviceAccountKey.json` in git, in a zip, or in a chat. It is the master key to the project.

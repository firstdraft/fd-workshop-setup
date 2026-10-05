# When something goes wrong (facilitator cheat sheet)

Symptom, then the fix. Run commands in the attendee's Ubuntu: ask their Claude session to run them, or open an Ubuntu
terminal. Background is in [INSTRUCTOR-NOTES.md](INSTRUCTOR-NOTES.md), and what the family social network app does
and does not include is in [its section there](INSTRUCTOR-NOTES.md#the-family-social-network-readme-part-3).

## Building

- **A compile is stuck, or compiling again (or saving the Plan) fails with `409` and `compilation_active`.** A compile
  normally takes 30 to 45 seconds. The error names the Compilation, as `current.compilation.id` or in the 409's
  `response.detail` ("Compilation `<id>` is already active..." or "Cancel active Compilation `<id>`..."). Run these in
  the app folder (or in its `.firstdraft/design` if the app was already compiled once):
  1. Once CLI 0.8.2 is installed (`firstdraft --version`; `npm install --global @firstdraft.com/cli@latest` updates
     it): `firstdraft compilation cancel <id>`, then compile again.
  2. CLI 0.8.1 has no cancel. Wait 3 minutes, then `firstdraft compilation status <id> --wait` (it returns when the
     Compilation finishes, or after 10 minutes). `succeeded`: `firstdraft compilation download <id> --output .`.
     `failed` or `cancelled`: compile again.
  3. Still `queued` or `running`: start a [fresh Project](#fresh-project) in a new folder, or
     [cancel it with the attendee's token](#cancel-with-the-attendees-token).
- **A compile ends with a 502, a timeout, `request_outcome_unknown` or `compilation_status_unavailable`.** Do not
  compile again while it may still be running. With `current.compilation.id` in the error, wait a minute, then run
  `firstdraft compilation status <id> --wait` and download it as above once it succeeds. With no ID, compiling once
  more is safe: while the first one is active, First Draft refuses with `409 compilation_active` and names it (row
  above). If anything else keeps the Project blocked, start a [fresh Project](#fresh-project).
- **`analyzer_release_mismatch`** (`foundation_plan.analysis.analyzer_release_mismatch`) right after a First Draft
  deploy: the Plan was analyzed while the deploy was switching releases. Compile again once. Do not deploy First
  Draft during the workshop.
- **Many compiles fail at the same time.** 30 compiles started within 5 seconds all succeeded after the 2026-10-03
  capacity upgrade; 50 is untested. With more than 30 people, start compiles by table, about a minute apart.

## Running and previewing

- **A native preview fails with `/up returned HTTP 403`, or `log/bin-dev.log` shows `Blocked hosts:
  ….trycloudflare.com`.** The web app was started without the tunnel's host. Stop it and start it as
  `RAILS_DEVELOPMENT_HOSTS=.trycloudflare.com bin/dev </dev/null >log/bin-dev.log 2>&1` (the attendee can type
  `Restart the web app.`).
- **Revyl says "Concurrency limit reached", or the helper says a preview session already exists.** The last phone is
  still shutting down. Wait 15 to 30 seconds, run `bin/<platform> preview revyl stop` again (or stop it on the Revyl
  dashboard under Sessions), then retry. Ignore the upgrade hint.
- **A photo upload fails with `KeyError: key not found: "CLOUDINARY_URL"`.** On the laptop: in the app folder, run
  `bash ~/.workshop/cloudinary.sh install .`, then restart the web app. If it prints `MISSING`, the attendee runs
  `/workshop-signin` in a new session first (it redoes only what is missing). On the live app: the Render service was
  created without the key, so delete it (`render services delete <service-id> --confirm`) and create it again with
  the same Neon project.
- **`cloudinary.sh save` keeps printing `INVALID`.** It wants three copies from the API Keys page, in this order: the
  copy button by **API environment variable**, the **API Key**, then the **API Secret** from the same row, shown
  with its eye button first (dots or stars are not the secret).

## Deploying

- **The first deploy fails with `function uuidv7() does not exist`.** The Neon database is PostgreSQL 17, a claimable
  database from `npx get-db` or neon.new. Create a PostgreSQL 18 project
  (`neonctl projects create --name <app> --region-id aws-us-east-2 --pg-version 18 -o json`), delete the Render
  service (`render services delete <service-id> --confirm`), and deploy again with the new project's direct
  connection string. The Render CLI cannot change a service's environment variables.
- **The live app is empty.** Expected: sample data and demo logins are development-only. Attendees sign up there.
- **The first CI run is red, or 20 or more Dependabot pull requests appear.** Harmless; ignore them.

## Setup and sign-in

- **A sign-up page (Revyl, Cloudinary) shows errors or a security check.** The venue network may be blocking it: have
  the attendee use a phone hotspot.
- **The sign-in skill has no Cloudinary step, or shows `[FAIL] cloudinary: helper not installed`.** The laptop was set
  up from an older zip. Download the zip again, open its `workshop-kit` folder in a Local session, type `continue`
  (it redoes the handoff; give the same app name), then run `/workshop-signin` again in a WSL session.

## Commands

### Fresh Project

For a Project that a stuck compile blocks. It copies the Plan into a new Project in a new folder; replace `APP` with
the app folder's name. An app compiled before keeps its Plan under `.firstdraft/design/.firstdraft/`, so the first two
lines pick that copy when it exists:

```sh
PLAN=~/APP/.firstdraft/design/.firstdraft/foundation-plan.json &&
{ [ -f "$PLAN" ] || PLAN=~/APP/.firstdraft/foundation-plan.json; } &&
mkdir ~/APP-2 && cd ~/APP-2 &&
firstdraft plan init --name "Fresh Project" &&
cp "$PLAN" .firstdraft/ &&
firstdraft plan compile
```

`plan init` only creates the new Project's ID; the copied Plan replaces its name. Then the attendee opens a new session
in `/home/appdev/APP-2` (WSL, Ubuntu-24.04) and continues from README step 11.

### Cancel with the attendee's token

For CLI 0.8.1. Run it where the stuck-compile commands run (the app folder, or its `.firstdraft/design`) after
replacing `COMPILATION_ID`. It reads the Project ID and the attendee's saved First Draft token from their files, sends
the token to First Draft only, and never prints it (`-q` ignores any `~/.curlrc`, which could turn on verbose output):

```sh
P=$(python3 -c 'import json; print(json.load(open(".firstdraft/state.json"))["project_id"])') &&
T=$(python3 -c 'import json, os; print(json.load(open(os.path.expanduser("~/.config/firstdraft/credentials.json")))["origins"]["https://firstdraft.com"]["access_token"])') &&
printf 'Authorization: Bearer %s\n' "$T" | curl -q -sS -X POST -H @- \
  "https://firstdraft.com/v1/projects/$P/compilations/COMPILATION_ID/cancel"
```

A reply with `"status":"cancelled"` frees the Project: compile again. `compilation_not_cancellable` means it had
already finished: check it with `firstdraft compilation status`.

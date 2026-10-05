# Instructor notes (not part of the zip)

During the workshop, use [FACILITATOR.md](FACILITATOR.md): symptoms and
their fixes.

Zip the contents of `workshop-kit/`, including the `.claude/` folder, but
**not** `logs/` or `state/` (they are created on each laptop).

## How it works

`CLAUDE.md` tells Claude to run `scripts/check-status.ps1`, do the one
`NEXT STEP` it prints, and repeat. Claude never improvises install commands.
After a restart, the attendee reopens the folder and types "continue"; the
status check works out where they are from the machine itself, not from
Claude's memory.

```
Claude Desktop, Windows session (this folder):
check-status -> ENABLE_VIRTUALIZATION -> prepare-bios (BitLocker suspend, reboot to UEFI)
             -> INSTALL_WSL           -> install-wsl (admin) -> RESTART
             -> SETUP_UBUNTU          -> setup-ubuntu (Ubuntu-24.04, user appdev/appdev, passwordless sudo)
             -> INSTALL_TOOLS         -> install-tools (Install phase)
             -> CONFIGURE             -> configure (git defaults, SSH key, GitHub host key)
             -> HANDOFF               -> verify, ask app name, handoff (app folder + skills in Ubuntu)
             -> DONE                  -> attendee opens a WSL session

Claude Desktop, WSL session (WSL > Ubuntu-24.04 > /home/appdev/<app>):
/workshop-signin -> GitHub (+ git name/email from the account, SSH key upload),
                    Render (+ CLI workspace, Render GitHub app), Neon,
                    Cloudinary (key saved from the clipboard), Revyl (+ browser sign-in),
                    First Draft (device code)
new WSL session  -> /create-full-stack-app <app idea>
```

WSL sessions in Claude Desktop use the Desktop app's Claude sign-in. (An
earlier version of these notes said WSL sessions do not support plugins; the
owner's testing on 2026-10-03 showed plugins are available when WSL is
selected.) The handoff still installs both skills as user skills in Ubuntu's
`~/.claude/skills`, which was tested and needs no plugin install:
`workshop-signin` (only loads when typed) and a link to the First Draft
plugin's one skill in its npm package. If an attendee also has the First
Draft plugin enabled, the session may list that skill twice.

The handoff also writes a block of notes for the app sessions into Ubuntu's
`~/.claude/CLAUDE.md` (from `scripts/linux/app-instructions.md`), because
every Claude session in Ubuntu loads that file without being asked:
- the web app started as `RAILS_DEVELOPMENT_HOSTS=.trycloudflare.com bin/dev`
  (in the background, stdin closed), so the preview tunnel can reach it;
- native preview with Revyl from WSL (GitHub builds the apps, one
  `cloudflared` quick tunnel per attendee, the Revyl browser sign-in for the
  Viewer link, the Render URL as the fallback `--server`);
- a short Render deploy recipe: a Neon PostgreSQL 18 project from `neonctl`
  and its direct connection string (never a claimable database, never
  pooled), `bin/rails secret`, `--confirm` on every `render` command, the
  `render services create` flags and environment variables, and polling
  `render deploys list` until live;
- photo and file uploads: `cloudinary.sh install .` puts the saved
  Cloudinary key in the app's `.env.development.local`, and the deploy
  sources the saved file into `render services create`.

A re-run replaces the block between its marker lines and leaves the rest of
the file alone. The check only looks for the block, so a laptop that already
has it picks up a newer version only when `handoff.ps1` runs again.

Cloudinary (photo and file uploads, read from `CLOUDINARY_URL`) has no CLI
sign-in, and its console shows the API environment variable only as a
format with `<your_api_key>` and `<your_api_secret>` placeholders. So the
sign-in skill has the attendee copy that format (for the cloud name), then
the API Key, then the API Secret, and runs `~/.workshop/cloudinary.sh save`
after each copy. The helper reads the Windows clipboard with
`powershell.exe Get-Clipboard`, asks Cloudinary's Admin API `ping` whether
it accepts the key (only a 401 rejects it; no answer still saves), writes
`~/.workshop/cloudinary.env` with mode 600, empties the clipboard, and
prints only `SAVED`, `NEXT` or `INVALID`, never the value.
`cloudinary.sh install` writes only into apps that use Cloudinary
(`config/initializers/cloudinary.rb`; `bin/lint-env` rejects the key in
other apps) and only where Git ignores `.env.development.local`.

`Setup WSL without Claude.cmd` runs the same scripts in a plain window, as a
fallback. It replaces the old `setup-wsl.cmd` / `setup-wsl.ps1` in this
folder, which can be deleted.

## The family social network (README Part 3)

The prompt is "Help me build a social network for just my family. It should work and look like Instagram so that
it's familiar." A rehearsal on 2026-10-03, against the Compiler then in Production, took about 8 minutes from prompt
to approved summary (allow 10 to 12 with real typing) and 31 seconds to compile. It produced a private app where
sign-in, the feed, posting, likes, comments, follows and profiles worked. "Make it look like Instagram" took about 3
minutes, and each of the three customization ideas in README step 15 took 1.5 to 2 minutes as a Rails edit.

Deployed on 2026-10-04 (Production bac4f3ff, plugin 0.8.3): sign-up without email verification, required user
fields on the sign-up form instead of dropping sign-in, and the redesigned interview (it asks the attendee's level
once, checks early what First Draft will and won't build, and asked 4 to 5 questions in three rehearsals). Still in
flight and not deployed at that point: phone apps with sign-in, photos, counts, guests redirected to sign-in, and
one-tap like/follow buttons.

What First Draft generated in that rehearsal:

- **Phone apps need a public list.** iPhone and Android clients show only pages anyone can see. If every list
  requires sign-in, no phone app is generated and README step 14 has nothing to show. Let visitors read posts
  without signing in; signing in is for posting.
- **Sign-up works on the live app** (since 2026-10-04): new accounts are signed in right away, with no email
  confirmation. The live app starts with no accounts, because sample data and demo logins are development-only, so
  attendees sign up there. Password-reset emails are not sent until the app has an email provider (`DEPLOY.md`
  "Account email").
- **Some things show up as gaps in the summary, not features:** photo or avatar uploads and like and follower
  counts, until those changes deploy. A required role or status on users no longer removes sign-in: since
  2026-10-04 it becomes a sign-up field or takes its default. Attendees can add the rest with Claude after Compile.
- **Restyling the generated app to match the design takes a long time** (about an hour in one colleague trial).
  README step 15 starts with one screen.
- The prompt has Claude unzip the design into the project folder from the Windows Downloads folder. Compiling into
  the current folder keeps the design under `.firstdraft/design/`.

## Facilitator notes from the 2026-10-03 rehearsal

Symptoms and their fixes, including this rehearsal's, are in
[FACILITATOR.md](FACILITATOR.md). Background:

- Revyl's Android device has WebView 152, which works. After a stop, the
  device stays listed for about 15 seconds; the helper refuses to start
  another until it clears, and then the next one starts normally (same or
  other platform).
- The Revyl Viewer link opens only in a browser signed in to Revyl with the
  CLI's account; the sign-in skill has attendees sign in on revyl.ai first,
  then approve the CLI sign-in in that browser.
- Revyl's free plan needs no card. Each account gets about 5 hours of iPhone
  or 6.25 hours of Android a month, and one device per platform at a time.
  A workshop uses a small part of that.
- Ask attendees, in the message before the workshop, to sign up for Revyl
  with GitHub from home and to create their own organization. People in one
  organization share its one device per platform and its monthly time.
- The local CSS rebuild (Tailwind watcher) worked on Linux in Core's gate.

## Tested so far

- All `.ps1` files parse under Windows PowerShell 5.1 and are ASCII-only; the
  `.sh` files pass `bash -n`.
- On this PC (Windows 11 Home, WSL 2.7.14 already installed, no distros):
  `check-status` reported SETUP_UBUNTU; `setup-ubuntu` installed Ubuntu-24.04
  and created `appdev` on the first try; `check-status` then reported VERIFY;
  `verify` printed RESULT: READY with all 19 checks passing. Running
  `setup-ubuntu` a second time was harmless, and `DefaultUid=1000`,
  `RunOOBE=0` were set.
- Not exercised here: `install-wsl`, `restart`, `prepare-bios` (WSL and
  virtualization were already on).
- Install phase (`install-tools`) on a fresh Ubuntu-24.04: about 4.5 minutes
  in total. mise downloaded a prebuilt Ruby 4.0.5 (14 seconds, no compiling).
  The first run stopped at Revyl, which installs to `~/.revyl/bin` and only
  adds that to `~/.bashrc`; that is fixed, and the re-run passed all 11
  components. `verify` then printed RESULT: READY, and every tool resolves in
  both login shells (how Claude runs commands) and interactive terminals.
- Configure phase (`configure`): refuses to run without a name and email
  (exit 40) and rejects a mistyped email (exit 41). With a test name
  containing an accent and an apostrophe, it set git identity and defaults,
  created an SSH key, and trusted github.com only after matching GitHub's
  published fingerprint. A re-run kept the same key. `ssh -T git@github.com`
  reached GitHub without prompting ("Permission denied (publickey)" is
  expected until the key is uploaded). `verify` printed RESULT: READY.
  This test Ubuntu still has the test identity `Zoë O'Test
  <workshop-test@example.com>`.
- (History: the next few notes describe the earlier terminal flow, where
  sign-in and building happened in Claude Code in an Ubuntu terminal. It was
  replaced by Claude Desktop WSL sessions; see the end of this list.)
- Handoff (`handoff`, `open-workshop`): asks for an app name when none is
  given (exit 40) and rejects invalid names (exit 41). With
  `firstdraft-workshop` it created the folder, installed the plugin, the
  sign-in checks and the `workshop` command, and the status check then said
  DONE. `open-workshop` opened a Windows Terminal window in which `workshop`
  started `claude --plugin-dir ~/.workshop/plugin /workshop:auth`.
- Sign-in checks (`auth.sh`): about 8 seconds, never opening a browser.
  `revyl auth status` exits 0 even when signed out, so the check reads its
  output. `neonctl me` starts a browser sign-in when signed out, so the check
  only runs it when Neon's saved credentials exist.
- Sign-in session (first manual test, with a placeholder skill): Claude
  could only show the Render, Neon and Revyl links after running each sign-in
  in the background and reading its log; Neon took three attempts because each
  restart makes a new link. The skill now uses `~/.workshop/login.sh`, which
  starts the sign-in detached, opens the Windows browser (`wslview`), prints
  the link and any one-time code, and returns. Tested against real output:
  GitHub (device link and code), Neon (OAuth link), Render and Revyl ("already
  signed in" is reported as finished). Revyl's banner prints a docs link
  first, so docs links are skipped. Cancelled attempts left no processes, and
  existing sign-ins were unaffected.
- Signed out: the helper captures Render's link and 16-character code and
  Revyl's link and code (skipping its docs link).
- Fixed: scripts piped into `bash -s` could have the rest of the script
  swallowed by any command that reads stdin. `Invoke-LinuxScript` now saves
  the script to a temp file and runs it with stdin closed.
- After the first sign-in session, `/exit` opened the second session (First
  Draft plugin) as intended.
- Not yet tested: `github-refresh`.
- First Draft sign-in (CLI 0.8.1, `firstdraft login`): the helper supports the
  default mode (the browser sends the approval back to a listener on
  127.0.0.1 in Ubuntu, as Neon's does) and `firstdraft-device`
  (`firstdraft login --device`). The skill now starts with the device code
  and falls back to the default mode, because WSL2's 127.0.0.1 forwarding
  fails on some machines. The CLI has no status
  command, so the check looks for `https://firstdraft.com` in
  `~/.config/firstdraft/credentials.json`. Link capture tested for both modes
  (not yet an approved sign-in). The Install phase now requires First Draft
  CLI 0.8.1 or newer, so a machine set up earlier gets updated.
- Revyl CLI pin: v0.1.133, bumped from v0.1.109 on 2026-10-03. It waits up
  to 35 minutes for a busy device queue (v0.1.109 gave up after 2) and no
  longer reports success for a stop the server did not confirm. The
  installer and the helper's flags are unchanged. Laptops set up earlier
  fail the `revyl` check, so `check-status` sends them to INSTALL_TOOLS,
  which installs v0.1.133; v0.1.109 still works on a laptop that is not
  re-run.
  - `tools.sh install revyl` on Ubuntu 24.04 (container): checksum
    verified, then the check passed.
  - Rehearsed on the owner's Mac with the official v0.1.133 macOS binary
    (checksum verified) and a free Revyl organization, against the
    rehearsal app's Render URL. Android started in 24 seconds (uploaded
    build reused) and showed the app; stop; iOS started in 30 seconds and
    showed the app; stop; then Android, stop, and Android again. No
    "Concurrency limit reached".
  - v0.1.133's stop prints `"stopped": false, "stop_requested": true` and
    exits 0 while the device shuts down; the session left
    `revyl device list` 13 to 15 seconds later. An Android start 5 seconds
    after the iOS stop was refused by the helper ("a preview session already
    exists") until then.
- The Neon skills installer writes to `./.claude/skills` in the folder it
  runs from, so the script runs it from `~` (user-wide skills). It also
  leaves `~/skills-lock.json` behind.
- Claude Desktop WSL session (tested by hand, with the skills installed into
  `~/.claude/skills`): it used the Desktop app's Claude sign-in; every tool
  was on the session's PATH; `/workshop-signin` loaded and ran the First
  Draft sign-in, which opened the default Windows browser and put the link on
  the clipboard; a new WSL session listed the First Draft skill.
- `login.sh` now opens every sign-in page itself with `wslview` (which runs
  Windows PowerShell `Start`, so the default Windows browser opens), falling
  back to `powershell.exe Start-Process`, and stops the CLIs opening their
  own (only Neon did). It copies the GitHub code, or the link for the other
  services, to the Windows clipboard with `clip.exe`.
- Git name and email are no longer asked for in the Configure phase. After
  the GitHub sign-in, `git-identity.sh` sets them from the account: its name
  (or username) and its private no-reply address,
  `<id>+<username>@users.noreply.github.com`. The `git-identity` sign-in
  check requires that address. The GitHub sign-in no longer asks for the
  `user:email` permission.
- Neon sign-in failing the first time on fresh installs: `neonctl auth`
  (7.0.1) closes its local listener for the browser's reply after a fixed 60
  seconds (`AUTH_TIMEOUT_SECONDS` in `neon/dist/auth.js`, not configurable).
  Creating a Neon account takes longer, so the first approval reached
  nothing; on the retry the attendee was already signed in and approved in
  time. It also always opens the link itself (the `open` package ignores
  `BROWSER`), so `login.sh` opened a second tab. Fix: `login.sh` no longer
  opens Neon's link (it still copies it) and warns that it expires; the
  sign-in skill has the attendee create or sign in to their Neon account
  first, then starts the sign-in; `login.sh status` reports a timeout.
  Not yet tested live (a test opens a tab, since neonctl always opens one).
- Render cannot be given access to a private repo from either CLI: Render's
  CLI has no such command, and GitHub's API for adding a repo to an app
  installation does not accept `gh`'s sign-in. The attendee uses
  https://github.com/apps/render/installations/new instead. The sign-in skill
  now opens that page right after the Render sign-in and asks for **All
  repositories**, since the app's repository is created later.
- `render login` does not choose a workspace, and most `render` commands then
  stop with "no workspace set". After the Render sign-in, the skill runs
  `render-workspace.sh`, which keeps a set workspace, sets the only one, or
  lists several (`ASK:`) for the attendee to choose; `auth.sh` checks it as
  `render-workspace`. Tested against a stubbed `render` (one, several, none,
  already set) and, read-only, against a real signed-in CLI (v2.22.0, which
  has the same `workspace set|current` and `workspaces -o json` as v2.28.0).
- First Draft's sign-in pages are behind the pre-alpha username and password
  (HTTP basic auth). Attendees get them on a handout; the skill tells them a
  username-and-password box appears and never handles the values. Current
  browsers do not show the "First Draft pre-alpha" realm text in that box,
  so the skill also describes it as a "Sign in" box for firstdraft.com.
- 2026-10-03 rehearsal on a Mac, acting as an attendee's agent (compile,
  GitHub, Render and Neon, Revyl Android and iOS, one iteration), changed the
  app-session notes:
  - `RAILS_DEVELOPMENT_HOSTS` in `.env.development.local` did not reach the
    host check (dotenv loads after Rails reads it), so the tunnel kept
    getting 403. Setting it on the `bin/dev` command line worked. A Core fix
    will make the file work for apps compiled later; the command-line form
    works either way.
  - `npx get-db` (Neon's claimable database) is PostgreSQL 17, and the deploy
    failed with `function uuidv7() does not exist`. It also prints the
    password and writes `./.env`.
  - `render services -o json` hung for over 2 minutes without a terminal;
    `render services list -o json --confirm` returned at once.
  - The notes' `render services create` flags worked: 3 seconds, then about
    1.6 minutes for the first Docker build.
- `cloudinary.sh` on Ubuntu 24.04 (container, 2026-10-04), with stubs for
  `powershell.exe` (the clipboard, with Windows line endings), `clip.exe`
  and, except for two real calls, Cloudinary's `ping`. `save` stored a
  whole value in one copy, and the console's format, API Key and API Secret
  in three copies, as one `CLOUDINARY_URL` line (mode 600), then emptied the
  clipboard. It printed `INVALID` and saved nothing for an empty clipboard,
  several lines, Cloudinary's docs examples, a hidden secret (dots or stars,
  even when `ping` could not be reached), shell metacharacters, a piece
  copied at the wrong step, and a key Cloudinary rejected (the real `ping`
  answered 401 for a fake key). No output contained any part of the value,
  even with a verbose `~/.curlrc` (`curl -q` ignores it), and the secret
  reached `curl` only on stdin. `install` replaced earlier `CLOUDINARY_URL`
  lines and kept the rest of `.env.development.local`, skipped an app
  without uploads, and refused a folder where Git does not ignore that file.
  `handoff.sh apply` (stubbed `npm`) installed the helper, and sourcing the
  saved file filled `--env-var "CLOUDINARY_URL=$CLOUDINARY_URL"`.
- FACILITATOR.md's cancel command (same container): it read the Project ID
  and token from sample files and sent the token only as the `Authorization`
  header, to a local server, without printing it, also with a verbose
  `~/.curlrc`. Production answers that route with
  `401 authentication_required` for a made-up token. The fresh-Project
  commands, with a stubbed `firstdraft`, compiled the Plan of an app never
  compiled and of one compiled before (from `.firstdraft/design/.firstdraft`)
  under a new Project ID.

## Test before the workshop (not yet verified)

1. **Fresh Windows 11 Home laptop:** the full flow end to end, especially that
   Claude Desktop's permission prompt for running scripts, the Windows admin
   prompt started by `Start-Process -Verb RunAs`, and waiting for it all
   behave as expected.
2. **`wsl --install -d Ubuntu-24.04 --no-launch`:** confirm the first-run
   questions never appear later (the scripts set `/etc/wsl.conf`, `DefaultUid`
   and `RunOOBE=0` to prevent them).
3. **BitLocker on Home "Device encryption":** `DisableKeyProtectors` suspends
   it, and changing the BIOS setting then boots without a recovery prompt.
   On this PC the non-admin check returned `0` (reported as Unknown), so the
   admin step does the precise check.
4. **`.claude/settings.json`:** the `PowerShell(...)` allow and deny rules
   match as intended (the wildcard syntax for the PowerShell tool is a guess).
5. **Windows 10 22H2:** the `wsl --install --no-distribution` and
   `--web-download` fallbacks.
6. **A company-managed laptop:** confirm it fails clearly and points to the
   instructor.
7. **Laptop with VT-x off:** `shutdown /r /fw` lands in the UEFI screen.
8. **The rewritten handoff on a fresh account:** that the WSL session picks up
   both skills, and that the skill's `allowed-tools` lets the helper scripts
   run without permission prompts (the rule syntax is a best guess).
9. **First Draft device sign-in with the handout credential:** the basic-auth
   box appears once, then GitHub, then the device approval, and the check
   passes.
10. **Render workspace and GitHub app on a fresh Render account:**
    `render-workspace.sh` sets the only workspace, and installing the Render
    GitHub app from GitHub's page links it to that Render account.
11. **App-session notes:** a new WSL session in the app folder loads the block
    in `~/.claude/CLAUDE.md`, starts the web app as
    `RAILS_DEVELOPMENT_HOSTS=.trycloudflare.com bin/dev`, previews Android
    then iOS through one quick tunnel, and deploys with a `neonctl`
    PostgreSQL 18 project, its direct string and `bin/rails secret`. Also that
    the session keeps `cloudflared` and the web app running in the
    background, and that `neonctl projects create` does not stop to ask for
    a Neon organization on a fresh account.
12. **Cloudinary on a fresh account, from a Claude Desktop WSL session:**
    Sign up with GitHub works; the API Keys page's copy buttons (API
    environment variable, API Key, then API Secret after the eye button and
    any confirmation) put the expected text on the clipboard;
    `cloudinary.sh save` reads it through the real `powershell.exe
    Get-Clipboard`, gets 200 from `ping`, and empties the clipboard with
    `clip.exe`. Then an app compiled with photo uploads stores a photo in
    development after `cloudinary.sh install .`, and on Render after a deploy
    that sources the saved file.

## Deliberate choices

- The handoff sets `permissions.defaultMode` to `auto` in Ubuntu's
  `~/.claude/settings.json`. WSL sessions read that file, and auto mode
  approves routine commands while still asking before risky ones (such as a
  deploy), so attendees are not asked to approve every step. The Desktop
  mode picker can still override it per folder.

- `appdev` gets passwordless sudo, so Claude can install packages later
  without a password prompt it cannot answer. The password `appdev` is still
  set for when attendees use a terminal themselves.
- Setup never changes an existing Ubuntu-24.04 with a different default user
  unless the attendee agrees (`-ReplaceExistingUser`).
- `setup-ubuntu.ps1` makes Ubuntu-24.04 the default WSL distro.
- Linux scripts are piped into bash with Windows line endings stripped, so
  editing them on Windows cannot break them.

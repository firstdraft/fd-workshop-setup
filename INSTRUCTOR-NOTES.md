# Instructor notes (not part of the zip)

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
/workshop-signin -> GitHub (+ git name/email from the account, SSH key upload), Render, Neon, Revyl, First Draft
new WSL session  -> /create-full-stack-app <app idea>
```

WSL sessions in Claude Desktop use the Desktop app's Claude sign-in, but do
not support plugins. So the handoff installs both skills as user skills in
Ubuntu's `~/.claude/skills`: `workshop-signin` (only loads when typed) and a
link to the First Draft plugin's one skill in its npm package.

`Setup WSL without Claude.cmd` runs the same scripts in a plain window, as a
fallback. It replaces the old `setup-wsl.cmd` / `setup-wsl.ps1` in this
folder, which can be deleted.

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
- First Draft sign-in (CLI 0.8.1, `firstdraft login`): the helper uses the
  default mode (the browser sends the approval back to a listener on
  127.0.0.1 in Ubuntu, as Neon's does), with `firstdraft-device`
  (`firstdraft login --device`) as the fallback. The CLI has no status
  command, so the check looks for `https://firstdraft.com` in
  `~/.config/firstdraft/credentials.json`. Link capture tested for both modes
  (not yet an approved sign-in). The Install phase now requires First Draft
  CLI 0.8.1 or newer, so a machine set up earlier gets updated.
- Revyl prints that v0.1.133 is available (pinned: v0.1.109).
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
  https://github.com/apps/render/installations/new instead.

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

## Deliberate choices

- `appdev` gets passwordless sudo, so Claude can install packages later
  without a password prompt it cannot answer. The password `appdev` is still
  set for when attendees use a terminal themselves.
- Setup never changes an existing Ubuntu-24.04 with a different default user
  unless the attendee agrees (`-ReplaceExistingUser`).
- `setup-ubuntu.ps1` makes Ubuntu-24.04 the default WSL distro.
- Linux scripts are piped into bash with Windows line endings stripped, so
  editing them on Windows cannot break them.

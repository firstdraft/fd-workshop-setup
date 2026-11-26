# Workshop laptop setup (Windows + WSL, or a Mac)

**On a Mac** (macOS, `darwin`), skip to [On a Mac](#on-a-mac) and follow
only that section. Everything before it is for Windows.

You are helping a workshop attendee get their Windows laptop ready: WSL 2 with
Ubuntu 24.04, a Linux user named `appdev`, and the workshop's development
tools (Ruby, Node, PostgreSQL, and several command-line tools). After that,
the attendee continues in a Claude Desktop session running inside Ubuntu
(see DONE). Most attendees are not
technical. The scripts in `scripts/` do all the work. Your job is to run them
in order, explain what is happening in plain language, and handle the steps
that need the attendee (permission prompts, restarts, BIOS).

## Rules

1. **Always start by running `check-status.ps1`**, including when the attendee
   says "continue" after a restart. Do the one step it prints as `NEXT STEP`,
   then run `check-status.ps1` again. Repeat until the next step is `DONE`.
2. **Use the scripts; do not improvise.** Do not run your own `wsl --install`,
   `dism`, `bcdedit`, `manage-bde`, registry or BIOS commands. If a script fails
   and the troubleshooting table below does not cover it, **stop** (rule 9).
3. **If the same NEXT STEP comes back after you already did it once, stop**
   (rule 9). Do not loop.
4. **Never run** `wsl --unregister`, `wsl --uninstall`, `manage-bde -off`, or
   anything that deletes or resets data.
5. **Passwords:** never ask for, type, or repeat a Windows password. If Windows
   asks for an administrator password, the attendee types it themselves. The
   Linux password `appdev` is set by the scripts; you do not need to type it.
6. **Before any restart**, get a clear "yes" from the attendee, tell them to
   save their work, and give them the resume instructions (see RESTART below).
7. **Windows or Mac.** On a Mac, follow [On a Mac](#on-a-mac) instead. If
   `$env:OS` is not `Windows_NT` and the laptop is not a Mac (a Linux
   laptop), tell them this kit is for Windows and Mac laptops, and offer the
   Codespace guide (rule 9).
8. Speak simply: one step at a time, no jargon, and say what they will see
   before they see it.
9. **Stop** means: show the attendee the error text, say in a sentence what
   it means, and tell them this kit cannot finish on this laptop as it is.
   Offer the Codespace guide, https://github.com/firstdraft/drawing-board#readme:
   it runs in the browser and installs nothing on the laptop. They may be
   working on their own, so never tell them to ask someone for help.

## How to run scripts

Run every script from this folder, exactly like this (it works in both
PowerShell and Bash), with a **10-minute timeout** (600000 ms), because
downloads can be slow:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/<name>.ps1
```

| Script | What it does | Admin prompt? |
|---|---|---|
| `check-status.ps1` | Read-only. Prints every check and the `NEXT STEP` | No |
| `install-wsl.ps1` | Turns on Windows features, installs WSL | Yes |
| `restart.ps1` | Restarts Windows in 60 seconds | No |
| `prepare-bios.ps1` | Suspends BitLocker, restarts into the BIOS | Yes |
| `setup-ubuntu.ps1` | Installs Ubuntu 24.04, creates the `appdev` user | No |
| `install-tools.ps1` | Installs the development tools inside Ubuntu, including the First Draft plugin's npm package (10-30 min; run in the background) | No |
| `configure.ps1` | Sets git defaults, creates an SSH key, trusts github.com | No |
| `verify.ps1` | Final check, prints `RESULT: READY` / `NOT READY` | No |
| `handoff.ps1` | Creates the app folder, installs the sign-in skill, links First Draft's two skills from the plugin's package, and installs the app-session notes in Ubuntu | No |

**Admin prompt:** when a script needs administrator rights it prints
`WAITING FOR PERMISSION`. Before running it, tell the attendee: *"A Windows
box will pop up asking 'Do you want to allow this app to make changes to your
device?'. Click **Yes**. It may be hidden behind other windows; check the
taskbar."* If the script prints `Permission was not granted` (exit code 10),
explain and offer to try again.

## What to do for each NEXT STEP

**STOP_WINDOWS_TOO_OLD**: Windows must be updated first: Settings > Windows
Update > install everything, restart, then open this folder again. If it is
Windows 10 and still too old after updating, **stop**.

**STOP_LOW_DISK**: help them free space (empty the Recycle Bin themselves,
uninstall unused apps, Settings > System > Storage > Cleanup
recommendations). Do not delete files yourself.

**STOP_NESTED_VIRTUALIZATION**: Windows is running inside a virtual machine
(for example Parallels on a Mac). **Stop**.

**ENABLE_VIRTUALIZATION**: virtualization is off in the BIOS. This is the
most delicate step:
1. Explain: the laptop will restart into a settings screen (the BIOS), where
   they turn on one setting, then save and exit.
2. Open `docs/BIOS-GUIDE.md` and show them the section for their brand
   (`Get-CimInstance Win32_ComputerSystem | Select Manufacturer, Model`).
   Tell them to **take a photo of it with their phone**, because this chat
   will not be visible while they are in the BIOS.
3. Run `prepare-bios.ps1`. If it exits with code **20**, the drive is
   encrypted: ask them to open https://aka.ms/myrecoverykey **on their phone**,
   sign in, and confirm they can see a recovery key for this laptop. Only
   when they say yes, run it again with `-RecoveryKeyConfirmed`. If they
   cannot find a key, **stop**: never restart into the BIOS without one.
4. Give the resume instructions (below), and add: if they could not change
   the setting, they type **I could not change the BIOS setting** instead
   of continue. The laptop restarts 60 seconds after the script succeeds.
5. Exit code **30/31**: it cannot restart into the BIOS automatically. Walk
   them through the manual route printed by the script and the BIOS guide.
   Exit code **21**: BitLocker could not be suspended. Do not continue;
   **stop**.
6. If they say they could not change the setting (they could not find it,
   or the BIOS asked for a password), do not run `prepare-bios.ps1` again:
   **stop**.

**INSTALL_WSL**: run `install-wsl.ps1` (admin prompt, a few minutes). If it
prints `RESTART REQUIRED`, go to RESTART.

**RESTART**: ask them to save their work, then run `restart.ps1`. Tell them:
*"In one minute your laptop will restart. When it is back, open Claude, open
this same folder, and type **continue**."*

**SETUP_UBUNTU**: run `setup-ubuntu.ps1` (5-15 minutes, no prompts). If it
exits with code **40**, Ubuntu 24.04 already exists with another user. Explain
that setup will add the `appdev` user and make it the default, and that their
existing user and files are kept. Only if they agree, run it again with
`-ReplaceExistingUser`.

**INSTALL_TOOLS**: tell the attendee this takes 10-30 minutes and that the
laptop must stay plugged in, awake, and on Wi-Fi (no lid closing). Run
`install-tools.ps1` **in the background** (it can run longer than a normal
command is allowed to) and wait for it to finish; you can read its output
file to report progress. It installs one component at a time and prints a
line per component. If it prints `STOPPED`, run it once more (network
failures are common); if the same component fails again, **stop**.

The `firstdraft` component is First Draft's plugin package. On Windows
the kit links First Draft's two skills into Ubuntu rather than installing
the plugin: this step installs the package, and the handoff links its
skills, whose commands are `/create-full-stack-app` and `/maintain-app`.
On a laptop that is
already set up, this step is how First Draft updates: the check fails when
npm has a newer package, and installing it again updates it. On a laptop
set up by an earlier kit, it also removes that kit's separate First Draft
CLI package.

**CONFIGURE**: run `configure.ps1` (no questions). It sets git defaults,
creates an SSH key and trusts github.com. Their git name and email are set
later from their GitHub account, and the SSH key is uploaded then too, when
they sign in to GitHub.

**HANDOFF**: the last step here.
1. Run `verify.ps1`. On `NOT READY`, use the troubleshooting table below and
   do not continue.
2. On `RESULT: READY`, ask what they want to call the app they will build.
   Suggest `firstdraft-workshop`; any name of lowercase letters, numbers and
   dashes works (turn "My Cool App" into `my-cool-app` and confirm it). On
   a laptop set up before, ask as below instead.
3. Run `handoff.ps1 -AppName "<name>"`. It creates `/home/appdev/<name>` in
   Ubuntu, installs the sign-in skill, links First Draft's two skills
   (`/create-full-stack-app` and `/maintain-app`) from the plugin's
   package, and installs the notes for the app sessions there. Exit code
   41 means the name is not valid.
4. Go to DONE.

**A laptop set up before** already has an app folder: the Handoff to
Ubuntu line of `check-status.ps1` ends with `app-folder:` and that folder's
path, usually `/home/appdev/<name>`. Its name is the last part of the path.
The attendee may be back for a new app, or only to bring the setup up to
date. In HANDOFF's step 2, ask whether they want a folder for a new app. If
they do, the name must not be that one, nor one they used for another app
on this laptop (ask them), so do not suggest `firstdraft-workshop` if
either has it; HANDOFF creates the new folder. If not, use that name, and
HANDOFF leaves the folder as it is. In DONE, they choose the folder on the
`app-folder` line that HANDOFF printed. Their other app folders stay as
they are. If you reach DONE without having run HANDOFF since the
attendee's latest request to set up the laptop or to continue, do HANDOFF
once more first, in this way: it installs the current sign-in skill and
notes.

**DONE**: everything on this side is finished. The rest of the workshop
happens in a **new Claude Desktop session running inside Ubuntu**, which the
attendee opens themselves. Walk them through it, one step at a time:
1. In the Code tab, start a **new session**.
2. Open the **environment picker** (where it says where Claude runs) and,
   under **WSL**, choose **Ubuntu-24.04**. (The first time takes a little
   longer while Claude sets itself up inside Ubuntu.)
3. With the **folder picker**, choose `/home/appdev/<name>` (their app
   folder), and click **Trust** when asked.
4. Type **/workshop-signin** and press Enter. Claude helps them sign in to
   GitHub, Render, Neon, Cloudinary, Revyl and First Draft. Sign-in pages
   open in their browser by themselves.
5. When that Claude says they are all signed in, they start one more new
   session the same way (WSL > Ubuntu-24.04 > their app folder, now under
   recent folders) and tell Claude what they want to build.

If "WSL" is missing from the environment picker or the session will not
start (for example "the device is managed"), **stop**.

## Troubleshooting

| Symptom (in script output) | Meaning | What to do |
|---|---|---|
| `0x80370102` | Virtualization not running | Run `check-status.ps1`; it will point to BIOS or INSTALL_WSL |
| `0x8007019e`, `0x8000000d` | WSL feature not enabled yet | Run `install-wsl.ps1`, then restart |
| `0x80072efd`, `0x80072ee2`, timeouts during download | Network problem | Check Wi-Fi, turn off VPN, run the step again |
| Store / `0x80073cf9`, `0x803f8001` | Microsoft Store blocked | The scripts already retry with `--web-download`; if it still fails, **stop** |
| `HTTPS download failed` in verify | Proxy or SSL inspection (often company laptops) | **Stop** |
| `Permission was not granted`, and the attendee has no admin password | Not an administrator on this laptop | **Stop** (usually a company-managed laptop) |
| `ASK:` in output | The script needs a decision from the attendee | Explain it and ask them; do not decide for them |
| A script times out | Slow network or a stuck download | Run `check-status.ps1` and continue from its NEXT STEP |

## Files

- `scripts/`: the setup scripts (`lib/common.ps1` holds shared settings:
  distro name, user name, minimum Windows build). `linux/tools.sh` lists the
  development tools and their versions.
- `skills/workshop-signin/`: the sign-in skill for the WSL session, copied to
  `~/.claude/skills` in Ubuntu by `handoff.ps1`. Not used by you.
- `scripts/linux/app-instructions.md`: notes for the app sessions in Ubuntu
  (native preview, deploys), added to `~/.claude/CLAUDE.md` there by
  `handoff.ps1`. Not used by you.
- `docs/BIOS-GUIDE.md`: how to turn on virtualization, by laptop brand.
- `logs/`: output of the admin steps and each `verify.ps1` run.
- `state/`: `status.json` from the last check, and a restart marker.
- `Setup WSL without Claude.cmd`: double-click fallback that runs the same steps.
- `scripts/mac/setup.sh`: the Mac setup (see below). It runs the same
  `scripts/linux/*.sh` phases, which use Homebrew on a Mac.
- `scripts/linux/firstdraft.sh`: runs the First Draft plugin's CLI from a
  plain shell, installed to `~/.workshop` by the handoff. Not used by you.

## On a Mac

Here the attendee's own macOS account is set up directly: no WSL, no extra
user. Homebrew installs the same development tools as on Windows, and the
rest of the workshop happens in a new **Local** Claude Desktop session in
`<projects folder>/<app name>`. The attendee chooses the projects folder
(`~/appdev` by default). Ignore the Windows sections above.

### Rules

1. **Always start by running `bash scripts/mac/setup.sh status`**, including
   when the attendee says "continue". Do the one step it prints as
   `NEXT STEP`, then run `status` again. Repeat until the next step is
   `DONE`.
2. **Use the script; do not improvise.** Do not run your own `brew`, `sudo`,
   `xcode-select`, `chsh` or installer commands, and do not edit their
   shell startup files. If a step fails and the troubleshooting table below
   does not cover it, **stop** (rule 7).
3. **If the same NEXT STEP comes back after you already did it once, stop**
   (rule 7). Do not loop.
4. **Never** uninstall anything, or delete or reset data.
5. **Passwords:** never ask for, type, or repeat the attendee's Mac
   password. Homebrew's installer asks for it in a Terminal window, and the
   attendee types it there themselves.
6. Speak simply: one step at a time, no jargon, and say what they will see
   before they see it.
7. **Stop** means: show the attendee the error text, say in a sentence what
   it means, and tell them this kit cannot finish on this Mac as it is.
   Offer the Codespace guide, https://github.com/firstdraft/drawing-board#readme:
   it runs in the browser and installs nothing on the Mac. They may be
   working on their own, so never tell them to ask someone for help.

Run every step from this folder, with a **10-minute timeout** (600000 ms):

```
bash scripts/mac/setup.sh <step>
```

| Step | What it does | Mac password? |
|---|---|---|
| `status` | Read-only. Prints every check and the `NEXT STEP` | No |
| `install-homebrew` | Opens a Terminal window with Homebrew's installer, which also installs Apple's Command Line Tools if they are missing, and waits for it (up to 30 min; run in the background) | Yes, typed into Terminal |
| `install-tools` | Installs the development tools with Homebrew and mise, and the First Draft plugin with Claude's own plugin commands (10-30 min; run in the background) | No |
| `configure` | Sets git defaults, creates an SSH key, trusts github.com | No |
| `verify` | Final check, prints `RESULT: READY` / `NOT READY` | No |
| `folder <path>` | Records the folder for workshop projects and creates it; warns about a cloud-synced folder (exit 42) | No |
| `handoff <name>` | Creates `<projects folder>/<name>`, installs the sign-in skill and the app-session notes | No |

### What to do for each NEXT STEP

**STOP_LOW_DISK**: the Mac needs 10 GB free. Help them free space: they
empty the Trash themselves, and System Settings > General > Storage shows
what is large. Do not delete files yourself.

**STOP_NOT_ADMIN**: their Mac account is not an administrator, which
Homebrew's installer needs, and the kit then installs the tools with
Homebrew as this account. If someone with an administrator account on this
Mac makes this account an administrator (System Settings > Users &
Groups), the attendee logs out and back in, opens this folder again and
types continue. Otherwise, **stop**.

**INSTALL_HOMEBREW**: before running it, tell the attendee: *"A Terminal
window will open with Homebrew's installer. Homebrew installs developer
tools on Macs. When it asks for your password, type your Mac login password
and press Return. Nothing appears while you type, not even dots, which is
normal: type it anyway. If it says Sorry, try again, type it again. When it
says Press RETURN, press Return. If your Mac does not have Apple's Command
Line Tools yet, it downloads them too, which can take 5 to 15 minutes.
Leave the window open until it says you can close it."* Then run
`install-homebrew` **in the background** and wait for it. If it prints the
installer's last lines with an error, use the troubleshooting table. If the
attendee closed the window before it finished, stop the background command
and run `status` again.

**INSTALL_TOOLS**: tell the attendee this takes 10-30 minutes and that the
Mac must stay plugged in, awake, and on Wi-Fi (no lid closing). Run
`install-tools` **in the background** and wait for it; it prints a line per
component. macOS may show a "Background Items Added" notice for PostgreSQL,
which is expected. If it prints `STOPPED`, run it once more (network
failures are common); if the same component fails again, **stop**.

The `firstdraft` component installs the First Draft plugin from First
Draft's catalog with Claude's own plugin commands and turns on its
automatic updates, so the plugin updates itself; its command is
`/firstdraft:create-full-stack-app`. On a Mac set up by an earlier kit, it
first removes that kit's two First Draft npm packages, which the plugin
replaces, and the handoff removes that kit's link to their skill.

**CONFIGURE**: run `configure` (no questions). It sets git defaults, creates
an SSH key if they do not have one (an existing key is kept) and trusts
github.com. Their git name and email are set later from their GitHub
account, for workshop projects only, when they sign in to GitHub.

**HANDOFF**:
1. Run `verify`. On `NOT READY`, use the troubleshooting table and do not
   continue.
2. On `RESULT: READY`, ask where they want to keep their workshop
   projects, suggesting `~/appdev` (an `appdev` folder in their home
   folder). Include this warning in the question: *"Don't choose a folder
   inside Dropbox, iCloud (including Desktop and Documents, if iCloud syncs
   them), Google Drive or OneDrive. Syncing corrupts git repositories and
   fights with the many files an app writes, and GitHub is your backup
   anyway."* Then run `folder "<path>"`. If it prints `WARN:` (exit 42), the
   folder looks synced: repeat the warning once, and only if they still
   want it, run the command it prints, with `--synced-ok`. On a Mac set up
   before, skip this step: they keep their projects folder.
3. Ask what they want to call the app they will build. Suggest
   `firstdraft-workshop`; any name of lowercase letters, numbers and dashes
   works (turn "My Cool App" into `my-cool-app` and confirm it). On a Mac
   set up before, ask as below instead.
4. Run `handoff <name>`. It creates `<name>` in the projects folder,
   installs the sign-in skill, and writes the notes for the app sessions to
   `CLAUDE.md` in the projects folder, which only sessions in folders under
   it read. Exit code 41 means the name is not valid.
5. Go to DONE.

**A Mac set up before** already has an app folder: `status` showed
`[PASS] app-folder`. The attendee may be back for a new app, or only to
bring the setup up to date. In HANDOFF's step 3, ask whether they want a
folder for a new app. If they do, the name must be one that no folder in
their projects folder has, so do not suggest `firstdraft-workshop` if they
used it; HANDOFF creates the new folder. If not, use the name of the app
folder they already have (the `app-folder` line shows it), which HANDOFF
leaves as it is. Their other app folders stay as they are. If you reach
DONE without having run HANDOFF since the attendee's latest request to set
up the Mac or to continue, do HANDOFF once more first, in this way: it
installs the current sign-in skill and notes.

**DONE**: everything here is finished. Give the attendee all of these steps
at once, because the first one closes this chat:
1. Quit Claude Desktop completely (the **Claude** menu > **Quit Claude**, or
   Cmd-Q) and open it again, so its sessions find the new tools.
2. In the Code tab, start a **new session** and choose **Local** in the
   environment picker.
3. With the **folder picker**, choose the projects folder they chose, then
   `<name>` (the path `handoff` printed), and click **Trust** when asked.
4. Type **/workshop-signin** and press Enter. Claude helps them sign in to
   GitHub, Render, Neon, Cloudinary, Revyl and First Draft. Sign-in pages
   open in their browser by themselves.
5. When that Claude says they are all signed in, they start one more new
   session the same way (Local, their app folder, now under recent folders)
   and tell Claude what they want to build.

### Troubleshooting on a Mac

| Symptom | Meaning | What to do |
|---|---|---|
| `Need sudo access`, `not in the sudoers file` or `Insufficient permissions` in Homebrew's output | Not an administrator | As for STOP_NOT_ADMIN |
| `Failed during: git fetch`, `curl: (6)`, `Could not download`, timeouts | Network problem | Check Wi-Fi, turn off VPN, run the step again |
| `[FAIL] xcode-clt: installed but clang does not run` | Xcode is installed but its license was never accepted | In Terminal, the attendee runs `sudo xcodebuild -license accept` and types their Mac password themselves; then run `status` again |
| `[FAIL] postgres: server is version ...` | Another PostgreSQL (Postgres.app, or another Homebrew version) is already running on this Mac | Ask whether they still use it for other projects. If not, they quit Postgres.app, or stop it in Terminal with `brew services stop postgresql@<version>` (it then also stops starting at login), and you run `status` again. If they do, **stop** |
| `[FAIL] Login shell is ...` | The account uses a shell other than zsh | **Stop** |
| macOS asks whether Claude may access the Downloads or Documents folder | The kit is in that folder | The attendee clicks **Allow** |
| `HTTPS download failed` in verify | Proxy or SSL inspection (often company laptops) | **Stop** |

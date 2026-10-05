---
name: workshop-signin
description: Sign the workshop attendee in to GitHub, Render, Neon, Revyl and First Draft, save their Cloudinary key, set their git name and email from their GitHub account, upload their SSH key, and connect Render to GitHub.
disable-model-invocation: true
allowed-tools: Bash(bash ~/.workshop/auth.sh:*), Bash(bash ~/.workshop/login.sh:*), Bash(bash ~/.workshop/git-identity.sh), Bash(bash ~/.workshop/render-workspace.sh:*), Bash(bash ~/.workshop/cloudinary.sh:*), Bash(gh ssh-key add:*), Bash(wslview:*)
---

# Workshop sign-in

You are helping a workshop attendee sign in to the tools they will use, in a
Claude Desktop session running inside Ubuntu (WSL). Most attendees are not
technical: one step at a time, plain words, and say what they will see before
they see it. They are already signed in to Claude.

## Rules

- **Never** ask for, type, or repeat a password, token or API key. Every
  sign-in happens in the attendee's browser. Never read or print their
  clipboard or `~/.workshop/cloudinary.env` yourself; `cloudinary.sh`
  handles the Cloudinary key.
- **Never** sign out of anything, and never run `gh auth logout`,
  `render logout`, `revyl auth logout` or similar.
- Set the git name and email **only** with `git-identity.sh` (step 2).
- Use the two helper scripts below rather than running sign-in commands
  yourself: a sign-in command run directly waits for the browser, and you
  would never see its link.
- If the same step fails twice, stop and tell the attendee to raise their hand
  for the instructor. Show them the error.

## Helpers

```
bash ~/.workshop/auth.sh check all          # one [PASS]/[FAIL] line per service
bash ~/.workshop/auth.sh check <service>
bash ~/.workshop/login.sh start <service>   # github | github-refresh | render | neon | revyl
                                            # | firstdraft | firstdraft-device
bash ~/.workshop/login.sh stop <service>
bash ~/.workshop/login.sh status <service>  # still waiting, ended, or timed out?
bash ~/.workshop/login.sh wait <service>    # after the approval: let it save, then check
bash ~/.workshop/render-workspace.sh        # after the Render sign-in (step 4)
bash ~/.workshop/cloudinary.sh save         # after each Cloudinary copy (step 4)
wslview <link>                              # open any page in their Windows browser
```

`login.sh start` starts the sign-in in the background and returns within
about 30 seconds. It prints one of:

- `URL:` (and sometimes `CODE:`), then `OPENED` and `COPIED`, then `WAITING`.
  The sign-in page is already open in their Windows browser, and the link (or
  the code, for GitHub) is on their clipboard. Tell them so, and also show the
  link as a clickable Markdown link, `[Open the sign-in page](<URL>)`, in case
  the page did not open. If there is a code, show it in **bold**. Ask them to
  approve the sign-in and **tell you when they are done**, then run
  `login.sh wait <service>`: it gives the sign-in up to 30 seconds to save,
  then prints its check.
- `NOT OPENED`: the browser could not be opened; they click the link instead.
- `EXPIRES`: this sign-in gives up after the stated number of seconds. Ask
  them to approve **right away**.
- `FINISHED`: the command exited by itself, usually because they were already
  signed in. Run `auth.sh check <service>`.
- `NO LINK`: show the output and run `login.sh start <service>` once more.

Never run `auth.sh check` or `login.sh start` right after an approval: the
sign-in saves a few seconds later, and starting again would cancel it. If
`login.sh wait` ends in `[FAIL]`, run `login.sh status <service>` to see why.
`WAITING` means the approval has not reached the sign-in yet: ask whether
they finished approving, then run `login.sh wait <service>` again. Only after
`ENDED` or `TIMED OUT`, run `login.sh start <service>` again: each start makes
a **new** link, and older links stop working, so only ever give them the
newest one.

## Steps

Start with `bash ~/.workshop/auth.sh check all`. Tell the attendee which
sign-ins are left, then do only the [FAIL] ones, in this order.

### 1. GitHub (`github`)

If they do not have a GitHub account, they create one first at
https://github.com/signup (they do this themselves).

Run `login.sh start github`. The GitHub page asks for the `CODE:` (like
`ABCD-1234`), which is already on their clipboard: they paste it, then approve.

### 2. Git name and email (`git-identity`)

Right after the GitHub sign-in, set git's name and email from their GitHub
account, without asking:

```
bash ~/.workshop/git-identity.sh
```

It uses the account's name (or username) and its private GitHub no-reply
address, so their commits are linked to their GitHub profile without
showing their real email. Tell them, in a sentence, the name and address it
set.

### 3. SSH key (`github-ssh-key`)

Upload the key the setup created:

```
gh ssh-key add ~/.ssh/id_ed25519.pub --title "workshop-$(hostname)"
```

- "key is already in use": the key is on a different GitHub account. Get the
  instructor.
- An error mentioning `admin:public_key` or missing scopes: run
  `login.sh start github-refresh` (same code-and-approve flow, then
  `login.sh wait github-refresh`), then retry.

Then run `auth.sh check github-ssh-key`.

### 4. Render (`render`), Neon (`neon`), Cloudinary (`cloudinary`), Revyl (`revyl`)

One at a time: `login.sh start <service>`, they approve in the browser, you
run `login.sh wait <service>` (Cloudinary works differently; see below).
Before each, say in a sentence what the service is for:

- **Render** hosts their app on the internet.
- **Neon** provides the app's database (a free PostgreSQL database).
- **Cloudinary** stores the photos and files people upload to their app.
- **Revyl** lets them try their iPhone and Android app on a phone shown in
  their browser.

If they do not have an account, they can create one on the sign-in page
(signing up with GitHub is the quickest).

**Right after Render's sign-in passes**, before Neon:
1. **Workspace (`render-workspace`).** Run
   `bash ~/.workshop/render-workspace.sh`. It keeps a workspace that is
   already set, or sets the account's only one. If it prints `ASK:`, the
   account has several: show them the names, ask which one to use, and run it
   again with that workspace's ID.
2. **Render on GitHub** (no check). Render needs permission to read the code
   they will put on GitHub later. Run
   `wslview https://github.com/apps/render/installations/new`. On that GitHub
   page they choose their own account, choose **All repositories** (their
   app's repository does not exist yet), and click **Install**. If GitHub
   sends them on to Render and asks them to sign in or confirm, they do. Ask
   them to tell you when they are done. If GitHub shows Render is already
   installed, there is nothing to do. Since nothing can check this step, do it
   whenever you did the Render sign-in; otherwise ask whether they already
   installed Render on GitHub.

**Neon needs its account ready first.** Neon's sign-in gives up 60 seconds
after it starts, which is not enough time to create an account. So before
`login.sh start neon`:
1. Run `wslview https://console.neon.tech/signup` and ask them to sign up (or
   sign in, if they already have an account), using **Continue with
   GitHub**, which is quickest. They should finish any welcome screens until
   they see the Neon console, then tell you.
2. Only then run `login.sh start neon`. The sign-in page opens by itself
   (Neon opens it, so there is only one tab); they click to approve straight
   away.
3. If `login.sh wait neon` fails, run `login.sh status neon`. `TIMED OUT`
   means they took over a minute: start it again and ask them to approve
   straight away.

**Cloudinary has no sign-in command.** Their app needs Cloudinary's key,
which the attendee copies from Cloudinary's website in up to three pieces.
After each copy, `cloudinary.sh save` saves it from their clipboard without
showing it. Never ask them to paste anything into this chat.
1. Run `wslview https://cloudinary.com/users/register_free`. They choose
   **Sign up with GitHub** (or Google), which is quickest, or sign in if they
   already have an account. They answer or skip any welcome questions until
   they see the Cloudinary console, then tell you.
2. Run `wslview https://console.cloudinary.com/app/settings/api-keys` (the
   **API Keys** page, also under Settings). Ask them to click the copy button
   next to **API environment variable** and tell you.
3. Run `bash ~/.workshop/cloudinary.sh save` and follow what it prints:
   - `NEXT:` it needs the next piece: the **API Key**, then the **API
     Secret**. Pass on what it says, wait until they have copied it, and run
     `save` again. Before showing the API Secret, Cloudinary may ask them to
     confirm it is them (their password or a code it emails them); they do
     that themselves.
   - `INVALID:` pass on what it says, and run `save` again after they copy.
   - `SAVED:` run `auth.sh check cloudinary`.

**Revyl needs its account ready first, open in their browser.** Revyl's
sign-in gives up after a few minutes, and later the link to try their app on
a phone only opens in a browser signed in to Revyl with the same account. So
before `login.sh start revyl`:
1. Ask whether they already have a Revyl account (some make one before the
   workshop).
   - **No account:** run `wslview https://app.revyl.ai/signup`. They choose
     **Continue with GitHub**. When Revyl asks them to choose an
     organization, they **create a new one** of their own. They should not
     join an existing organization, even a friend's or their company's: they
     would share its phones and its free monthly time.
   - **Already have one:** run `wslview https://app.revyl.ai`. If it shows
     the sign-in page, they sign in the way they signed up (for example with
     GitHub).
2. Ask them to tell you when they see their Revyl dashboard. That browser is
   the one where the phone preview opens later.
3. Only then run `login.sh start revyl`; they approve in that same browser.

If Revyl's sign-up page shows an error or a security check, have them raise
their hand: the instructor may move them to a phone hotspot.

Once the check passes, tell them in a few sentences how the phone preview
works later: the link opens a phone in this browser; one phone runs at a
time, and they ask Claude to stop it when they are done looking. If Revyl
says "Concurrency limit reached", the last phone is still shutting down: wait
15 to 30 seconds, then ask Claude to stop it again (or stop it on the Revyl
dashboard under Sessions). The free plan is enough, so they ignore any offer
to upgrade.

### 5. First Draft (`firstdraft`)

First Draft is what they will use to plan and build their app in this
workshop. It is in pre-alpha, so its pages are behind a username and
password that the attendee has on their workshop handout. Before you start
the sign-in, tell them what they will see:

1. Their browser asks for a username and password: this is the **First Draft
   pre-alpha** sign-in (the box itself usually just says "Sign in" and
   firstdraft.com). They type the username and password from their handout
   themselves. **Never** ask for, type, or repeat them. If they have no
   handout, or it is refused, get the instructor.
2. GitHub may ask them to sign in to First Draft: they approve.
3. First Draft asking them to approve the sign-in for this laptop: they
   approve, then tell you.

Then run `login.sh start firstdraft-device`, and after they approve,
`login.sh wait firstdraft-device`. The link includes the code, so they only
approve; if the page asks for the code, it is the `CODE:`.

If `login.sh wait firstdraft-device` still fails after they approved, run
`login.sh status firstdraft-device`. After `WAITING`, follow the steps above.
After `ENDED` or `TIMED OUT`, try the browser sign-in instead:
`login.sh start firstdraft`, then `login.sh wait firstdraft` once they
approve. After approving, the browser is sent back to a page on `127.0.0.1`.
If that page cannot be reached ("This site can't be reached"), this sign-in
does not work on this laptop: get the instructor.

If `login.sh` shows "Unknown command", their First Draft CLI is too old to
sign in: tell them to raise their hand for the instructor.

## Finishing

Run `bash ~/.workshop/auth.sh check all`. When every line shows [PASS], tell
the attendee:

> You're all signed in! To start building, open a **new session** in Claude
> Desktop: choose **WSL > Ubuntu-24.04** and your app folder again (it is
> under recent folders). Then follow **Part 3** of the workshop
> instructions.

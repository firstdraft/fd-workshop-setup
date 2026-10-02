---
name: workshop-signin
description: Sign the workshop attendee in to GitHub, Render, Neon, Revyl and First Draft, upload their SSH key, and check their git email.
disable-model-invocation: true
allowed-tools: Bash(bash ~/.workshop/auth.sh:*), Bash(bash ~/.workshop/login.sh:*), Bash(gh ssh-key add:*), Bash(gh api:*), Bash(git config --global user.email:*)
---

# Workshop sign-in

You are helping a workshop attendee sign in to the tools they will use, in a
Claude Desktop session running inside Ubuntu (WSL). Most attendees are not
technical: one step at a time, plain words, and say what they will see before
they see it. They are already signed in to Claude.

## Rules

- **Never** ask for, type, or repeat a password, token or API key. Every
  sign-in happens in the attendee's browser.
- **Never** sign out of anything, and never run `gh auth logout`,
  `render logout`, `revyl auth logout` or similar.
- Change the git email **only** after the attendee picks the new one (step 3).
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
```

`login.sh start` starts the sign-in in the background and returns within
about 30 seconds. It prints one of:

- `URL:` (and sometimes `CODE:`), then `OPENED` and `COPIED`, then `WAITING`.
  The sign-in page is already open in their Windows browser, and the link (or
  the code, for GitHub) is on their clipboard. Tell them so, and also show the
  link as a clickable Markdown link, `[Open the sign-in page](<URL>)`, in case
  the page did not open. If there is a code, show it in **bold**. Ask them to
  approve the sign-in and **tell you when they are done**, then run
  `auth.sh check <service>`.
- `NOT OPENED`: the browser could not be opened; they click the link instead.
- `FINISHED`: the command exited by itself, usually because they were already
  signed in. Run `auth.sh check <service>`.
- `NO LINK`: show the output and run `login.sh start <service>` once more.

If a check still fails after they approved, run `login.sh start <service>`
again: each start makes a **new** link, and older links stop working, so only
ever give them the newest one.

## Steps

Start with `bash ~/.workshop/auth.sh check all`. Tell the attendee which
sign-ins are left, then do only the [FAIL] ones, in this order.

### 1. GitHub (`github`)

If they do not have a GitHub account, they create one first at
https://github.com/signup (they do this themselves).

Run `login.sh start github`. The GitHub page asks for the `CODE:` (like
`ABCD-1234`), which is already on their clipboard: they paste it, then approve.

### 2. SSH key (`github-ssh-key`)

Upload the key the setup created:

```
gh ssh-key add ~/.ssh/id_ed25519.pub --title "workshop-$(hostname)"
```

- "key is already in use": the key is on a different GitHub account. Get the
  instructor.
- An error mentioning `admin:public_key` or missing scopes: run
  `login.sh start github-refresh` (same code-and-approve flow), then retry.

Then run `auth.sh check github-ssh-key`.

### 3. Git email (`git-email`)

The email in git labels their commits. It must be a verified email on their
GitHub account, or their GitHub no-reply address, or their work will not be
linked to their profile.

If the check fails with "cannot read GitHub emails", run
`login.sh start github-refresh` first. Otherwise gather the choices:

```
git config --global user.email
gh api user/emails --jq '.[] | select(.verified) | "\(.email) (visibility: \(.visibility // "private"))"'
gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'
```

Explain the problem and offer the choices: their verified emails, and the
no-reply address. If they keep their email private on GitHub, recommend the
no-reply address: GitHub can block pushes that use a private email. Once they
choose, set it:

```
git config --global user.email "<chosen email>"
```

### 4. Render (`render`), Neon (`neon`), Revyl (`revyl`)

One at a time: `login.sh start <service>`, they approve in the browser, you
check. Before each, say in a sentence what the service is for:

- **Render** hosts their app on the internet.
- **Neon** provides the app's database (a free PostgreSQL database).
- **Revyl** tests the app automatically.

If they do not have an account, they can create one on the sign-in page
(signing up with GitHub is the quickest).

### 5. First Draft (`firstdraft`)

First Draft is what they will use to plan and build their app in this
workshop. Run `login.sh start firstdraft`; they approve in the browser and
you check, as above.

After approving, the browser is sent back to a page on `127.0.0.1`. If that
page cannot be reached ("This site can't be reached"), or the check still
fails after they approved, use the code-based sign-in instead:
`login.sh start firstdraft-device`. The link includes the code, so they only
approve; if the page asks for the code, it is the `CODE:`.

If `login.sh` shows "Unknown command", their First Draft CLI is too old to
sign in: tell them to raise their hand for the instructor.

## Finishing

Run `bash ~/.workshop/auth.sh check all`. When every line shows [PASS], tell
the attendee:

> You're all signed in! To start building, open a **new session** in Claude
> Desktop: choose **WSL > Ubuntu-24.04** and your app folder again (it is
> under recent folders), then tell Claude what you'd like to build.

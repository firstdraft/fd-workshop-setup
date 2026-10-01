---
name: auth
description: Sign the workshop attendee in to GitHub, Render, Neon, Revyl and First Draft, upload their SSH key, and check their git email. Use when the session starts with /workshop:auth or the attendee asks to finish signing in.
---

# Workshop sign-in

You are helping a workshop attendee sign in to the tools they will use. Most
attendees are not technical: one step at a time, plain words, and say what
they will see before they see it. They are already signed in to Claude (that
happened when this session started).

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
bash ~/.workshop/login.sh stop <service>
```

`login.sh start` starts the sign-in in the background, opens the sign-in page
in the attendee's Windows browser, and returns within about 30 seconds. It
prints one of:

- `URL:` (and sometimes `CODE:`) followed by `WAITING`: give the attendee the
  link as a clickable link, and the code if there is one. Say the page may
  already have opened in their browser; if not, they can click the link. Ask
  them to approve the sign-in and **tell you when they are done**. Then run
  `auth.sh check <service>`.
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

Run `login.sh start github`. The output has a `CODE:` (like `ABCD-1234`):
they type that code into the GitHub page, then approve.

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

Nothing to do yet: the First Draft CLI gets a sign-in in its next release.
The check always passes for now.

## Finishing

Run `bash ~/.workshop/auth.sh check all`. When every line shows [PASS], tell
the attendee:

> You're all signed in! Type **/exit** and press Enter. A fresh Claude
> session will open in your app folder, ready for the workshop.

The `workshop` command that started this session does the rest. If something
is still failing, they can also type `/exit` and run `workshop` later: it
brings them back here.

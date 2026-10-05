# Workshop apps on this laptop (Ubuntu in WSL on Windows, or a Mac)

Added by the workshop kit. Where these notes differ from an app's own guides or a Neon skill, follow these notes.

## Files the user downloaded
- On Windows, files the user downloads are in their Windows Downloads folder:
  `"$(wslpath "$(wslvar USERPROFILE)")/Downloads"` (`wslvar` comes with `wslu`). On a Mac they are in
  `~/Downloads`, and macOS may ask the user to allow access to it. Copy or unzip from there.
- A new project folder goes next to the current one, in the same parent folder, where these notes apply.
- Unzip a design into the project folder before the first Compile. Compiling into the current folder keeps it
  under `.firstdraft/design/`.

## Web app
- Start the web app in the background and keep it running all session:
  `RAILS_DEVELOPMENT_HOSTS=.trycloudflare.com bin/dev </dev/null >log/bin-dev.log 2>&1`.
  The variable lets the preview tunnel reach the app. If the web app is already running without it, stop it and
  start it this way, once.
- On a Mac, also put `WATCHMAN_SOCK=/dev/null` in front of that command. Homebrew's `watchman`, when installed,
  stalls the CSS watcher (tailwindlabs/tailwindcss#17246), and the first page then fails with
  `The asset 'application.css' was not found in the load path`. If it already did, run `npm run build:css` once.
- Do not run `bin/ci` while the web app is running: its setup step reinstalls JavaScript packages and stops the
  JavaScript watcher. Stop the web app, run `bin/ci`, then start the web app again as above.

## Photo and file uploads (Cloudinary)
- An app with uploads (`config/initializers/cloudinary.rb` exists) needs `CLOUDINARY_URL`. The sign-in saved the
  user's key in `~/.workshop/cloudinary.env`. Never print it, show a file that holds it, or ask the user for it.
- Before starting such an app's web app, run `bash ~/.workshop/cloudinary.sh install .`. It writes the key into
  `.env.development.local` without printing it; restart the web app if it was already running. If it prints
  `MISSING`, the user runs `/workshop-signin` in a new session (it redoes only what is missing), then run it again.
- An upload failing with `KeyError: key not found: "CLOUDINARY_URL"` means the key is missing: locally, run the
  install above; on Render, the service was created without it, so delete it and create it again with the recipe,
  reusing the same Neon project.

## iPhone and Android preview
- Preview both with Revyl. GitHub builds the app from the pushed commit: do not install Xcode, a JDK, the Android
  SDK or an Emulator, and skip the guides' Emulator, Codespace and Mac steps.
- Start one tunnel in the background and keep it all session: `cloudflared tunnel --url http://localhost:3000`.
  Its `https://<name>.trycloudflare.com` URL replaces the guides' Codespace port 3000. Check that `<URL>/up`
  returns 200. A new address can take up to 2 minutes to resolve: on `Could not resolve host`, retry every 10
  seconds for up to 2 minutes instead of starting another tunnel. A 403 means the web app was started without
  `RAILS_DEVELOPMENT_HOSTS`: restart it as above.
- Commit and push (with `git push -u` if the helper asks for an upstream), then run
  `bin/android preview revyl --server <URL>` (or `bin/ios ...`) and give the user the printed Viewer link.
- Tell the user to open the Viewer link in the browser already signed in to revyl.ai with the same Revyl account as
  the CLI (`revyl auth status` shows it). If Revyl asks them to sign in, they sign in with that account.
- If the user has no Revyl account yet, they sign up at `https://app.revyl.ai/signup` with Continue with GitHub and
  create their own organization (never join someone else's), then sign the CLI in with `revyl auth login`.
- One Revyl device at a time, and stop it as soon as the user is done looking: `bin/<platform> preview revyl stop`.
  Stop output with `"stop_requested": true` and `"stopped": false` is normal: the device takes about 15 seconds to
  shut down. Wait until `revyl device list --json` prints `[]` before starting another device; the helper refuses
  while one is listed. An `"error"` key or a non-zero exit means the stop failed: run it again.
- "Concurrency limit reached" means the previous device is still shutting down. Wait 15-30 seconds, run the stop
  again (or have the user stop it on the Revyl dashboard under Sessions), then retry. Ignore any upgrade hint: the
  free plan is enough. Never suggest a paid plan or adding a card.
- If cloudflared cannot create a tunnel (rate limited: 429 or error 1015), use the app's Render URL as `--server`
  instead, retrying once if it is waking up. The preview then shows the deployed app's data.
- If Android shows "Update Required", stop the device and tell the user. Never sign in to Google Play.

## Deploying to Render
- Follow the "Deploy from the command line" section of the app's `DEPLOY.md`, with these additions:
- Each app gets its own Render workspace, because Render's 750 free instance hours a month are per workspace and
  running out suspends every free web service in it. The Render CLI cannot create a workspace, so before an app's
  first deploy, run `bash ~/.workshop/open.sh https://dashboard.render.com` and have the user create one: the
  workspace switcher, then **New workspace**, the **Hobby** plan (no monthly fee), named after the app. Then run
  `render workspaces -o json --confirm` and `render workspace set <ID> --confirm` with its ID. The sign-in's
  workspace only makes the CLI work. Before later `render` commands for an app, set its workspace again if another
  app's is active.
- Render allows five Hobby workspaces per account. If the **New workspace** form shows Hobby as "Limit reached" and
  offers Pro instead, never choose Pro or any paid plan. Deploy into an existing workspace instead, the one with the
  fewest free web services, and tell the user the app shares that workspace's 750 free hours.
- Never use `npx get-db`, `neon-new`, neon.new, `neon claim` or any other claimable or no-account database: they run
  PostgreSQL 17, and the deploy fails with `function uuidv7() does not exist`. Use the new Neon project on
  PostgreSQL 18 that `DEPLOY.md` creates, and its direct connection string, not pooled, even where the Neon skills
  advise pooled.
- `neonctl projects create` stops at "What organization would you like to use?" unless it is given one, and every
  new Neon account has an organization. Run `neonctl orgs list -o json` first and add `--org-id <id>` to
  `DEPLOY.md`'s `projects create` command.
- Pass `--confirm` to every `render` command, and `-o json` when you read its output; without them it can wait for
  input forever. List services with `render services list -o json --confirm`.
- Keep the database URL, `SECRET_KEY_BASE` and `CLOUDINARY_URL` in shell variables, as `DEPLOY.md` does, and never
  print them. For an app with uploads, skip `DEPLOY.md`'s `read -rs CLOUDINARY_URL`: start the same one command with
  `. ~/.workshop/cloudinary.env &&`, which sets the variable for `--env-var "CLOUDINARY_URL=$CLOUDINARY_URL"`.
- If Render cannot reach the GitHub repository, the user adds it to Render's GitHub app:
  `bash ~/.workshop/open.sh https://github.com/apps/render/installations/new`. A new workspace may need its own
  GitHub connection: if Render still cannot see the repository, they connect GitHub in that workspace's settings on
  the Render dashboard.
- Give the user the live URL when the newest deploy is `live`. The deployed app starts empty: sample records are
  for development only.

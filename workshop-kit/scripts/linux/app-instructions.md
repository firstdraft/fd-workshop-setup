# Workshop apps on this laptop (Ubuntu in WSL)

Added by the workshop kit. Where these notes differ from an app's own guides or a Neon skill, follow these notes.

## Files the user downloaded
- Files the user downloads in Windows are in their Windows Downloads folder:
  `"$(wslpath "$(wslvar USERPROFILE)")/Downloads"` (`wslvar` comes with `wslu`). Copy or unzip from there.
- Unzip a design into the project folder before the first Compile. Compiling into the current folder keeps it
  under `.firstdraft/design/`.

## Web app
- Before starting the web app, make sure the css line in `Procfile.dev` is
  `css: npm run build:css -- --watch=always`. With plain `--watch`, Tailwind exits when stdin closes and stops Rails.
- Start the web app in the background and keep it running all session:
  `RAILS_DEVELOPMENT_HOSTS=.trycloudflare.com bin/dev </dev/null >log/bin-dev.log 2>&1`.
  The variable lets the preview tunnel reach the app. Set it only on the command line: in `.env.development.local`
  it is read too late in apps compiled so far. If the web app is already running, stop it and start it this way, once.

- Do not run `bin/ci` while the web app is running: its setup step reinstalls JavaScript packages and stops the
  JavaScript watcher. Stop the web app, run `bin/ci`, then start the web app again as above.

## iPhone and Android preview
- Preview both with Revyl. GitHub builds the app from the pushed commit: do not install Xcode, a JDK, the Android
  SDK or an Emulator, and skip the guides' Emulator, Codespace and Mac steps.
- Start one tunnel in the background and keep it all session: `cloudflared tunnel --url http://localhost:3000`.
  Its `https://<name>.trycloudflare.com` URL replaces the guides' Codespace port 3000. Check that `<URL>/up`
  returns 200. A 403 means the web app was started without `RAILS_DEVELOPMENT_HOSTS`: restart it as above.
- Commit and push (with `git push -u` if the helper asks for an upstream), then run
  `bin/android preview revyl --server <URL>` (or `bin/ios ...`) and give the user the printed Viewer link.
- Tell the user the Viewer link opens only in a browser signed in to revyl.ai with the same Revyl account as the CLI
  (`revyl auth status` shows it). If Revyl asks them to sign in, they sign in with that account.
- One Revyl device at a time: run `bin/<platform> preview revyl stop` and wait until `revyl device list --json` is
  empty before starting the other platform. On a concurrency-limit error, wait a minute and retry once.
- If cloudflared cannot create a tunnel (rate limited: 429 or error 1015), use the app's Render URL as `--server`
  instead, retrying once if it is waking up. The preview then shows the deployed app's data.
- If Android shows "Update Required", stop the device and tell the user. Never sign in to Google Play.

## Deploying to Render
- The database is a new Neon project on PostgreSQL 18; the app needs its `uuidv7()`. Never use `npx get-db`,
  `neon-new`, neon.new, `neon claim` or any other claimable or no-account database: they run PostgreSQL 17, and the
  deploy fails with `function uuidv7() does not exist`. Create the project with
  `neonctl projects create --name <app> --region-id aws-us-east-2 --pg-version 18 -o json` (prints its ID).
- Use the direct connection string, `neonctl connection-string --project-id <id>`: no `--pooled`, no `-pooler` in
  the host. The Neon skills advise pooled, but this app runs its migrations at boot from this one URL.
- Pass `--confirm` to every `render` command, and `-o json` when you read its output; without them it can wait for
  input forever. List services with `render services list -o json --confirm`. The sign-in set the workspace; if a
  command says none is set, run `render workspaces -o json --confirm`, then `render workspace set <ID> --confirm`.
- Create the service in one command, so the secrets stay in shell variables and are never printed. Use the
  repository's https URL, not the `git@` remote:
  ```sh
  db=$(neonctl connection-string --project-id <id>) && secret=$(bin/rails secret) &&
  render services create --name <app> --type web_service --runtime docker \
    --repo https://github.com/<owner>/<repo> --branch main --plan free --region ohio \
    --health-check-path /ready --auto-deploy -o json --confirm \
    --env-var "DATABASE_URL=$db" --env-var "SECRET_KEY_BASE=$secret" --env-var PORT=80 \
    --env-var RAILS_ENV=production --env-var WEB_CONCURRENCY=0 --env-var RAILS_MAX_THREADS=3 \
    --env-var DB_POOL=8 --env-var SOLID_QUEUE_IN_PUMA=true --env-var RAILS_LOG_LEVEL=info \
    --env-var BUNDLE_WITHOUT=development:test
  ```
- Creating the service starts the first deploy; do not start another, which cancels it. Poll
  `render deploys list <service-id> -o json --confirm` until the newest is `live` (a few minutes), check
  `https://<name>.onrender.com/ready`, and give the user the URL. The deployed app starts empty: sample records are
  for development only. If the deploy fails, read `render logs -r <service-id> -o json --confirm`.
- Environment variables cannot be changed from the CLI later. If one is wrong, ask the user, then delete the service
  (`render services delete <service-id> --confirm`) and create it again.
- If Render cannot reach the GitHub repository, the user adds it to Render's GitHub app:
  `wslview https://github.com/apps/render/installations/new`.

# Workshop apps on this laptop (Ubuntu in WSL)

Added by the workshop kit. Where these notes differ from an app's own guides, follow these notes.

## Web app
- Before starting the web app in the background, make sure the css line in `Procfile.dev` is
  `css: npm run build:css -- --watch=always`. With plain `--watch`, Tailwind exits when stdin closes and stops Rails.

## iPhone and Android preview
- Preview both with Revyl. GitHub builds the app from the pushed commit: do not install Xcode, a JDK, the Android
  SDK or an Emulator, and skip the guides' Emulator, Codespace and Mac steps.
- Once per app: add `RAILS_DEVELOPMENT_HOSTS=.trycloudflare.com` to `.env.development.local`, then restart the web
  app if it is running.
- Start one tunnel in the background and keep it all session: `cloudflared tunnel --url http://localhost:3000`.
  Its `https://<name>.trycloudflare.com` URL replaces the guides' Codespace port 3000. Check that `<URL>/up`
  returns 200.
- Commit and push (with `git push -u` if the helper asks for an upstream), then run
  `bin/android preview revyl --server <URL>` (or `bin/ios ...`) and give the user the printed Viewer link.
- One Revyl device at a time: run `bin/<platform> preview revyl stop` and wait until `revyl device list --json` is
  empty before starting the other platform. On a concurrency-limit error, wait a minute and retry once.
- If cloudflared cannot create a tunnel (rate limited: 429 or error 1015), use the app's Render URL as `--server`
  instead, retrying once if it is waking up. The preview then shows the deployed app's data.
- If Android shows "Update Required", stop the device and tell the user. Never sign in to Google Play.

## Deploying to Render
- Follow the "Deploy from the command line" section of the app's `DEPLOY.md`.
- Use Neon's direct connection string (no `-pooler` in the host), even where a Neon skill suggests the pooled one.
- Generate `SECRET_KEY_BASE` with `bin/rails secret`; only a Render Blueprint generates one for you.
- If Render cannot reach the GitHub repository, the user adds it to Render's GitHub app:
  `wslview https://github.com/apps/render/installations/new`.

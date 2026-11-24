# launch-kit

Take an app you built with an AI tool — Lovable, Bolt, Replit, Cursor, v0,
Claude Code — and run it in production on your own server.

You get one `deploy/` folder in your project:

| Part | What it does |
| --- | --- |
| **HTTPS on your domain** | Caddy gets and renews the certificate by itself |
| **Your app in a container** | the same image on your machine and on the server |
| **Postgres** (optional) | on the server, or keep the hosted database you already use |
| **Backups** | a dump every night, kept 14 days; works for Supabase / Neon too; optional copy to S3-compatible storage |
| **Logs and metrics** (optional) | Grafana with one dashboard: requests, errors, response time, CPU, memory, disk, the app's logs |
| **Deploys** | every push to `main` through GitHub Actions, or one command from your machine |
| **Server setup** | one script: Docker, firewall, security updates, swap |

One server, one compose file, no Kubernetes. A 2 GB VPS is enough for the app
and the database; take 4 GB with the monitoring part.

## With Claude Code

```
/plugin marketplace add DVO-corp/launch-kit
/plugin install launch-kit@dvo
```

Open your project and say **"launch this app to production"** (or run
`/launch-kit:launch`). Claude reads the project, writes the Dockerfile, installs
the stack, prepares the server, deploys, and then proves it: HTTPS answers, a
backup exists, the dashboard shows your requests. It asks before touching your
server, DNS or GitHub settings, and it checks for the usual mistakes of AI-built
apps first — secrets in the browser bundle, `.env` in git, data that disappears
on redeploy.

## By hand

```bash
cp -R skills/launch/template  /path/to/your-project/deploy
cd /path/to/your-project/deploy
cp .env.example .env          # set DOMAIN, passwords, COMPOSE_PROFILES
cp app.env.example app.env    # your app's variables
```

Your project needs a `Dockerfile` at its root
([recipes](skills/launch/references/dockerfiles.md)). Then:

```bash
ssh root@SERVER 'bash -s' < deploy/scripts/server-setup.sh   # once
deploy/scripts/deploy.sh root@SERVER                          # every deploy
```

Create `deploy/.env` and `deploy/app.env` on the server before the first deploy
(`/opt/apps/<project>/deploy/`); they are never copied from your machine or
stored in git.

To try it locally first, set `DOMAIN=localhost` and run
`docker compose up -d --build` in `deploy/` — the [example](example) app works
for that.

### Everyday commands (in `deploy/` on the server)

```bash
docker compose ps                                           # what is running
docker compose logs -f app                                  # the app's logs
docker compose exec backup bash /backup.sh now              # dump the database now
docker compose exec backup bash /backup.sh list             # the dumps
docker compose exec backup bash /backup.sh restore <file>   # load a dump back
```

Grafana is not public. Open a tunnel and go to http://localhost:3001
(user `admin`, password from `.env`):

```bash
ssh -L 3001:127.0.0.1:3001 root@SERVER
```

## What it does not do

- **No alerts.** There is a dashboard, nobody is woken up when the site is down.
  Add an external uptime check on your domain at the very least.
- **One server.** If it dies, the app is down until you rebuild it from the backups.
- **A deploy restarts the app** — a few seconds of errors.
- **Nobody watches it**: disk space, image updates and the bill are yours.

## Don't want to run it yourself?

This kit is maintained by [DVO](https://dvocorp.com), a DevOps team that runs
production infrastructure for other people's products. If you would rather hand
it over — or you have outgrown one server — write to us: https://dvocorp.com or
Telegram [@dvocorp](https://t.me/dvocorp).

## License

MIT

# Dockerfile recipes

Pick the one that matches the project and adapt paths and commands to what the
project really uses (`package.json` scripts, lock file, entry module). In every
recipe the app listens on `0.0.0.0:$PORT`; `deploy/.env` sets `APP_PORT`, compose
passes it as `PORT`.

Variables with a `VITE_` / `NEXT_PUBLIC_` prefix are baked in at **build** time:
they must be `ARG`s in the Dockerfile (and build args in CI), not entries of
`app.env`. Only public values belong there.

## Static front end (Vite, React, Vue, Svelte — typical Lovable / Bolt export)

The build output is served by a small web server with a fallback to
`index.html`, so client-side routes work on reload.

```dockerfile
FROM node:26-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# Public build-time values, e.g. the Supabase URL and anon key.
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
RUN npm run build

FROM caddy:2.11.9-alpine
COPY --from=build /app/dist /srv
RUN printf ':{$PORT:3000} {\n\troot * /srv\n\tencode zstd gzip\n\ttry_files {path} /index.html\n\tfile_server\n}\n' > /etc/caddy/Caddyfile
```

## Next.js

Needs `output: "standalone"` in `next.config`.

```dockerfile
FROM node:26-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:26-alpine
WORKDIR /app
ENV NODE_ENV=production HOSTNAME=0.0.0.0
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
USER node
CMD ["node", "server.js"]
```

## Node server (Express, Fastify, Hono, NestJS)

```dockerfile
FROM node:26-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
USER node
CMD ["node", "server.js"]
```

If the project is TypeScript with a build step, build in a first stage (as in the
Next.js recipe) and copy `dist/` into the final one.

## Python (FastAPI, Flask, Django)

```dockerfile
FROM python:3.15-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home app
USER app
# FastAPI:
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-3000}"]
# Flask / Django: gunicorn -b 0.0.0.0:${PORT:-3000} app:app   (wsgi module of the project)
```

## Things that bite

- **Files written at run time** (SQLite, uploads) need a volume on the `app`
  service in `deploy/compose.yaml`, or they are lost on every deploy.
- **Migrations**: run them in the start command before the server, or as a
  one-off `docker compose run --rm app <migrate command>` in the deploy step.
- **Health**: if the app has a health URL, add a `healthcheck` to the `app`
  service so `docker compose ps` tells the truth.
- **Memory**: a Next.js or Vite build can need more than 2 GB. Build in CI
  (the GitHub workflow does) instead of on a small server.

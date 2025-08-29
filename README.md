# Claude Code — Monorepo (iOS + Backend)

This repository bundles the **iOS SwiftUI app** and the **Claude Code API** backend in one place,
with a Docker-first setup and a mounted `files/workspace` directory for project files.

## Layout
```
.
├─ apps/
│  └─ ios/                    # Xcode project (SwiftUI) + sources & scripts
├─ services/
│  └─ backend/
│     └─ claude-code-api/     # Upstream backend (see note below)
├─ deploy/
│  ├─ docker/Dockerfile.api   # Docker build for backend (clones pinned ref by default)
│  └─ compose/docker-compose.yml
├─ files/workspace/           # Host directory mounted at /workspace in the container
├─ scripts/                   # helper scripts
├─ docs/                      # All specification markdown files
├─ .env.example
└─ Makefile
```

### Important (backend source)
The **full upstream backend source** (`codingworkflow/claude-code-api`) is not mirrored here by default.
The included Dockerfile will **clone a pinned ref** during `docker build`. If you want a *vendored* copy
inside `services/backend/claude-code-api/`, run:

```bash
./scripts/fetch_backend.sh
```

This vendors the repository at the ref configured in the script. The GPL-3.0 license is preserved.

---

## Backend (Docker)

1) Configure environment:
```bash
cp .env.example .env
# edit .env and set ANTHROPIC_API_KEY=sk-...
```

2) Build & run:
```bash
docker compose -f deploy/compose/docker-compose.yml up --build -d
docker compose -f deploy/compose/docker-compose.yml logs -f api
```

3) Smoke test:
```bash
curl -sS http://localhost:8000/health
curl -sS http://localhost:8000/v1/models
```

The container mounts `./files/workspace` to `/workspace`.

---

## iOS App (SwiftUI)

1) Generate & open the Xcode project:
```bash
cd apps/ios
./Scripts/bootstrap.sh
```

2) In the app, open **Settings** and set:
- Base URL: `http://localhost:8000`
- API Key: your key (stored in Keychain)

### ATS (dev only)
Add an ATS exception for local HTTP if needed (already configured in `Info.plist` for dev).

---

## Communication (Client ⇄ Server)
- **Chat**: `POST /v1/chat/completions` (`stream=true` for SSE) • `GET /v1/chat/completions/{id}/status` • `DELETE /v1/chat/completions/{id}`
- **Projects**: `/v1/projects*` • **Sessions**: `/v1/sessions*` • **Models**: `/v1/models*` • **Health**: `/health`
The SSE shape matches the spec in `docs/01-Backend-API.md` and the Swift data models in `docs/02-Swift-Data-Models.md`.

See `docs/` for the complete product spec, wireframes, and MCP configuration notes.

# Selfhosted GitHub Runner – Docker Setup

Self-hosted GitHub Actions Runner für persönliche Repositories auf einem Raspberry Pi (oder jedem anderen Linux-Host). Jeder Runner läuft als eigener Docker-Container und registriert sich automatisch bei seinem Repository.

---

## Funktionsweise

```
docker-compose.yml        →  Basis-Konfiguration (Anchor &runner-base)
docker-compose.override.yml  →  Deine Repositories (wird nie committed)
.env                      →  Secrets (wird nie committed)
Dockerfile                →  Ubuntu + GitHub Runner Binary
start.sh                  →  Token holen, registrieren, starten
```

Docker Compose liest `docker-compose.yml` und `docker-compose.override.yml` automatisch zusammen. Jeder Service in der `override.yml` wird zu einem eigenständigen Runner-Container.

---

## Setup

### 1. Repository klonen

```bash
git clone https://github.com/TheFelodin/Selfhosted_Github_Runner_Docker_Setup
cd Selfhosted_Github_Runner_Docker_Setup
```

### 2. `.env` anlegen

```bash
cp .env.example .env
```

`.env` befüllen:

```env
ACCESS_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx   # GitHub Personal Access Token
DOCKER_GID=998                          # getent group docker | cut -d: -f3
```

Der Personal Access Token benötigt die Scopes `repo` und `workflow`. Erstellen unter:
[github.com/settings/tokens](https://github.com/settings/tokens)

### 3. `docker-compose.override.yml` anlegen

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
```

Eigene Repositories eintragen (siehe Abschnitt [Services konfigurieren](#services-konfigurieren)).

### 4. Image bauen und starten

```bash
docker compose up -d --build
```

Runner tauchen danach unter `Settings → Actions → Runners` im jeweiligen Repository auf.

---

## Services konfigurieren

Alle Services kommen in die `docker-compose.override.yml`. Pro Repository ein Service-Block:

```yaml
services:
  mein-repo:
    <<: *runner-base
    environment:
      REPO_NAME: mein-repo                       # Runner-Name und Label
      REPO_URL: https://github.com/USER/mein-repo
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - mein-repo:/github/workspace

      # Optional: App-Verzeichnis für Deploy-Jobs
      # - /stacks/mein-repo:/opt/app

      # Optional: SSH Deploy Key für private Repos
      # - /home/pi/.ssh/github_deploy:/home/runner/.ssh/id_ed25519:ro

volumes:
  mein-repo:
```

`REPO_NAME` wird automatisch als Runner-Name **und** als Label registriert. Mehrere Repositories einfach als weitere Service-Blöcke anhängen.

### Neuen Service hinzufügen

```bash
# 1. override.yml editieren – neuen Block eintragen
# 2. Nur der neue Container wird gestartet, bestehende bleiben unberührt:
docker compose up -d
```

---

## Workflows konfigurieren

Damit ein Workflow auf dem richtigen Runner landet, `runs-on` wie folgt setzen:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, "${{ github.event.repository.name }}"]
```

`github.event.repository.name` entspricht dem Repository-Namen – dieser muss mit `REPO_NAME` in der `override.yml` übereinstimmen.

### Empfohlene Workflow-Konfiguration

Parallel-Jobs bei schnell aufeinanderfolgenden Pushes automatisch abbrechen:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: [self-hosted, "${{ github.event.repository.name }}"]
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: docker compose -f /stacks/${{ github.event.repository.name }}/docker-compose.yml up -d --build
```

---

## Dateien im Überblick

| Datei | Committed | Zweck |
|---|---|---|
| `Dockerfile` | ✅ | Ubuntu-Image mit Runner-Binary und Docker CLI |
| `start.sh` | ✅ | Token holen, Runner registrieren, starten |
| `docker-compose.yml` | ✅ | Basis-Anchor `&runner-base` |
| `docker-compose.override.yml.example` | ✅ | Vorlage für eigene Services |
| `docker-compose.override.yml` | ❌ | Eigene Services (host-spezifisch) |
| `.env.example` | ✅ | Vorlage für Secrets |
| `.env` | ❌ | Secrets (ACCESS_TOKEN, DOCKER_GID) |

---

## Token-Verwaltung

`start.sh` holt beim Start automatisch ein frisches Runner-Token über die GitHub API (`ACCESS_TOKEN`). Der Runner-Token selbst läuft nach ~1h ab, wird aber im Hintergrund alle 50 Minuten erneuert ohne den Container neu starten zu müssen.

---

## Voraussetzungen

- Docker und Docker Compose auf dem Host
- GitHub Personal Access Token mit `repo` und `workflow` Scopes
- Docker-GID des Hosts (`getent group docker | cut -d: -f3`)
# Selfhosted GitHub Runner – Docker Setup

Self-hosted GitHub Actions Runner für persönliche Repositories auf einem Raspberry Pi (oder jedem anderen Linux-Host). Jeder Runner läuft als eigener Docker-Container und registriert sich automatisch bei seinem Repository.

---

## Funktionsweise

```
docker-compose.yml   →  Anchor &runner-base + alle Runner-Services
.env                 →  Secrets (wird nie committed)
Dockerfile           →  Ubuntu + GitHub Runner Binary
start.sh             →  Token holen, registrieren, starten
```

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

### 3. Repos in `docker-compose.yml` eintragen

Services und Volumes für eigene Repositories ergänzen – ein Block pro Repo (Beispiel ist bereits auskommentiert enthalten).

### 4. Image bauen und starten

```bash
docker compose up -d --build
```

Runner tauchen danach unter `Settings → Actions → Runners` im jeweiligen Repository auf.

---

## Neues Repository anbinden

1. Service-Block in `docker-compose.yml` ergänzen:

```yaml
  mein-repo:
    <<: *runner-base
    environment:
      REPO_NAME: mein-repo
      REPO_URL: https://github.com/USER/mein-repo
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - mein-repo:/github/workspace
```

2. Volume ergänzen:

```yaml
volumes:
  mein-repo:
```

3. Nur der neue Container wird gestartet, bestehende bleiben unberührt:

```bash
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

`github.event.repository.name` entspricht dem Repository-Namen – dieser muss mit `REPO_NAME` in der `docker-compose.yml` übereinstimmen.

### Empfohlene Workflow-Konfiguration

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    ...

  test:
    runs-on: ubuntu-latest
    ...

  deploy:
    needs: [lint, test]
    runs-on: [self-hosted, "${{ github.event.repository.name }}"]
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.ref_name }}
      - name: Deploy
        run: |
          docker compose down --remove-orphans
          docker compose up -d --build
          docker image prune -f
```

---

## Dateien im Überblick

| Datei | Committed | Zweck |
|---|---|---|
| `Dockerfile` | ✅ | Ubuntu-Image mit Runner-Binary und Docker CLI |
| `start.sh` | ✅ | Token holen, Runner registrieren, starten |
| `docker-compose.yml` | ✅ | Basis-Anchor + alle Runner-Services |
| `.env.example` | ✅ | Vorlage für Secrets |
| `.env` | ❌ | Secrets (ACCESS_TOKEN, DOCKER_GID) |

---

## Token-Verwaltung

`start.sh` holt beim Start automatisch ein frisches Runner-Token über die GitHub API (`ACCESS_TOKEN`). Der Token wird alle 50 Minuten im Hintergrund erneuert ohne den Container neu starten zu müssen.

---

## Deployment

Dieses Repo wird **einmalig manuell** auf dem Pi eingerichtet – ein automatisches Deployment via Pipeline wäre ein Henne-Ei-Problem, da der Runner der deployen soll erst durch dieses Setup entsteht.

Updates einspielen:

```bash
cd Selfhosted_Github_Runner_Docker_Setup
git pull
docker compose up -d --build
```

---

## Voraussetzungen

- Docker und Docker Compose auf dem Host
- GitHub Personal Access Token mit `repo` und `workflow` Scopes
- Docker-GID des Hosts (`getent group docker | cut -d: -f3`)
# Archipel — Software Factory

> Pipeline de développement AI-first pour side projects personnels et projets Club Med.
> Orchestré par Claude Code — zéro revue humaine entre les étapes.

---

## Archipel Live — Dashboard temps réel

Visualise en direct le pipeline, les agents, les hooks et les événements de chaque projet.

![Archipel Live](tools/archipel-live-screenshot.png)

```bash
npm run monitor          # serveur SSE → http://localhost:3999
cd apps/web && npm run dev   # dashboard  → http://localhost:3998/monitor
```

Mode démo (sans monitor) : `http://localhost:3998/monitor?demo=true`

→ **[Documentation complète](tools/README.md)**

---

## Vue d'ensemble

Archipel est une **factory**, pas une application. Elle génère des projets complets (Next.js + FastAPI + PostgreSQL) via un pipeline d'agents IA spécialisés, gouvernés par des hooks déterministes.

```mermaid
graph LR
    IDEA["💡 Idée"] --> DISCOVER["/discover"]
    DISCOVER --> SPEC["/spec"]
    SPEC --> DESIGN["/design"]
    DESIGN --> FEATURE["/feature"]
    FEATURE --> REVIEW["/review"]
    REVIEW --> QA["/qa"]
    QA --> SHIP["/ship 🚀"]

    style IDEA fill:#1a1a2e,color:#eee,stroke:#444
    style SHIP fill:#16213e,color:#eee,stroke:#0f3460
```

---

## Pipeline

```mermaid
flowchart TD
    B["/bootstrap\nWizard interactif\n→ .archipel/project.json"] --> D

    D["/discover\nDiscovery Agent\n→ brief.md + go/no-go"]
    D --> S

    S["/spec\nPM/PO + Architect\n→ PRD.md + ADR.md + Jira"]
    S --> DS

    DS["/design\nDesigner Agent\n→ DRD.md flows + composants"]
    DS --> F

    F["/feature\nDeveloper Agent\n→ Code + tests + migrations"]
    F --> R

    R["/review\n5 dimensions en parallèle\n→ rapport merge OK/KO"]
    R --> Q

    Q["/qa\nQA Agent\n→ QA report + validation"]
    Q --> SH

    SH["/ship\nDual-deploy\n→ GCP ou Azure"]

    style B fill:#2d4a1e,color:#fff,stroke:#4a7c35
    style SH fill:#1e3a5f,color:#fff,stroke:#2d6099
```

| Commande | Agent | Livrable | Mode |
|---|---|---|---|
| `/bootstrap` | — | `.archipel/project.json` | Wizard interactif |
| `/adopt` | — | `project.json` + adoption-plan | Rétro-analyse |
| `/modernize` | Modernization Agent | Projet V2 from scratch | Human-AI collab |
| `/discover` | Discovery Agent | `brief.md` + go/no-go | Human+AI |
| `/spec` | PM/PO + Architect | `PRD.md` + `ADR.md` + Jira | Human-AI collab |
| `/design` | Designer Agent | `DRD.md` (flows + composants) | Human-AI collab |
| `/feature` | Developer Agent | Code + tests + migrations | AI-led |
| `/review` | Reviewer Orchestrator | Rapport 5 dimensions | Human-AI collab |
| `/qa` | QA Agent | QA report + validation | AI-led + Human |
| `/ship` | — | Deploy prod | AI-led |

---

## Architecture des agents

38 agents spécialisés organisés en 10 couches. Le `build-orchestrator` les invoque dans l'ordre selon le contenu du plan `IMPL-*.md` — jamais en dur, toujours par détection contextuelle.

```mermaid
flowchart TD
    USER["👤 Nicolas Caussin"] --> BO

    subgraph PIPELINE["/feature — Pipeline complet"]
        BO["build-orchestrator\nOrchestre, ne code jamais"] --> ARCH
        ARCH["architect → IMPL-*.md"]

        ARCH --> DB_STEP
        subgraph DB_STEP["DB (conditionnel)"]
            DB["db-dev\nModèles + migrations"]
            DBA["dba\nOptimisation requêtes"]
            VDB["vector-db-dev\nEmbeddings + pgvector"]
        end

        DB_STEP --> DEV
        subgraph DEV["Développement (parallèle)"]
            NX["nextjs-dev\n+ vercel:nextjs patterns"]
            FA["fastapi-dev"]
            IOS["ios-dev"]
            AND["android-dev"]
        end

        DEV --> SPEC
        subgraph SPEC["Agents spécialisés (détectés via IMPL)"]
            AU["auth-dev\nJWT / Azure AD SSO"]
            WS["websocket-dev\nReal-time / SSE"]
            WK["worker-dev\nJobs async"]
            CA["cache-dev\nRedis"]
            IN["integration-dev\nWebhooks / APIs tierces"]
            AG["api-gateway-dev\nNginx / rate limiting"]
            AN["analytics-dev\nDashboards / time series"]
        end

        SPEC --> TW
        subgraph TW["Tests (parallèle)"]
            TW1["test-writer\ncoverage ≥ 80%"]
            CT["contract-tester\nContrats API"]
            PT["perf-tester\nk6 load tests"]
            A11["accessibility\nWCAG 2.1 AA"]
        end

        TW --> REVIEW
        subgraph REVIEW["Review 5 dimensions (parallèle)"]
            RS["security"]
            RA["architecture"]
            RP["performance"]
            RM["maintainability"]
            RR["resilience"]
        end

        REVIEW --> OBS
        subgraph OBS["Observabilité + Docs (parallèle)"]
            MON["monitoring-dev\nOTel + Sentry/Azure Monitor"]
            DOC["doc-writer\nOpenAPI + CHANGELOG + ADR"]
        end

        OBS --> COST["cost-analyzer\nCoût tokens + cloud"]
    end

    subgraph DESIGN["/design — Avant /feature"]
        CR["creative-director\n→ CREATIVE-BRIEF.md"]
        DSS["design-system\n→ DESIGN-SYSTEM.md"]
        UI["ui-designer\n→ UI-SPECS.md"]
        DR["design-reviewer\nValidation post-impl"]
        CR --> DSS --> UI
    end

    subgraph INFRA["Infrastructure (conditionnel)"]
        DEV2["devops\nDockerfiles + CI/CD"]
        GCP["infra-gcp\nCloud Run + Cloud SQL"]
        AZR["infra-azure\nContainer Apps + Azure DB"]
        TF["terraform-dev\nIaC GCP/Azure"]
    end

    style BO fill:#1e3a5f,color:#fff
    style ARCH fill:#2d4a1e,color:#fff
    style COST fill:#4a2d1e,color:#fff
```

### Catalogue complet — 38 agents

#### Orchestration
| Agent | Rôle |
|---|---|
| `build-orchestrator` | Orchestre l'intégralité du build. Ne touche jamais au code. Délègue tout. |
| `architect` | Produit `docs/IMPL-*.md` — le plan technique consommé par tous les agents dev. |

#### Design
| Agent | Rôle | Déclenchement |
|---|---|---|
| `creative-director` | Direction visuelle, palette, typographie → `CREATIVE-BRIEF.md` | Si CREATIVE-BRIEF absent |
| `design-system` | Tokens Tailwind, globals.css, composants métier → `DESIGN-SYSTEM.md` | Si DESIGN-SYSTEM absent |
| `ui-designer` | Specs de composants ultra-précises, layout ASCII → `UI-SPECS.md` | Si UI-SPECS absent |
| `design-reviewer` | Vérifie que le code frontend correspond aux specs pixel-perfect | Après nextjs-dev |

#### Frontend
| Agent | Rôle | Déclenchement |
|---|---|---|
| `nextjs-dev` | Next.js 16 App Router, Server Components, Server Actions. Applique les patterns officiels Vercel via `vercel:nextjs`. | Stack nextjs |
| `ios-dev` | Swift 5.9+ / SwiftUI / URLSession / MSAL Azure AD pour clubmed | Stack ios/swift |
| `android-dev` | Kotlin / Jetpack Compose / Retrofit / MSAL Android pour clubmed | Stack android/kotlin |
| `accessibility` | Audit WCAG 2.1 AA : ARIA, contraste, navigation clavier, VoiceOver | Après nextjs-dev si composants UI |

#### Backend
| Agent | Rôle | Déclenchement |
|---|---|---|
| `fastapi-dev` | Routers → Services → Repositories. Async partout, Pydantic v2, ruff clean. | Stack fastapi |
| `auth-dev` | OAuth2, JWT, RBAC. Azure AD SSO (clubmed) / PyJWT (perso). Middleware FastAPI + next-auth. | Mots-clés : auth, login, JWT, SSO, RBAC |
| `websocket-dev` | WebSocket FastAPI, ConnectionManager, broadcast, SSE. Reconnexion React avec backoff. | Mots-clés : websocket, real-time, SSE |
| `worker-dev` | Workers async héritant de `BaseWorker`. Redis BLPOP, DLQ, stateless + idempotent. | Mots-clés : worker, queue, async job |
| `cache-dev` | Redis async, cache-aside, stampede protection, `revalidateTag` Next.js. | Mots-clés : cache, Redis, revalidate |
| `integration-dev` | Webhooks HMAC, idempotency keys, retry avec backoff, circuit breaker. | Mots-clés : webhook, external API |
| `api-gateway-dev` | Nginx rate limiting, Traefik labels, middlewares FastAPI (RequestID, CORS, logging). | Mots-clés : rate limiting, nginx, gateway |

#### Data
| Agent | Rôle | Déclenchement |
|---|---|---|
| `db-dev` | Modèles SQLAlchemy, migrations Alembic async, schéma Prisma, index dès la création. | Si schéma DB dans IMPL |
| `dba` | Optimisation PostgreSQL : EXPLAIN ANALYZE, index CONCURRENTLY, détection N+1. | Après db-dev si jointures complexes |
| `vector-db-dev` | pgvector : colonnes `vector(1536)`, index HNSW/IVFFlat, RAG patterns, embeddings batch. | Mots-clés : embedding, vector, pgvector |
| `analytics-dev` | CTEs, window functions, time series, requêtes Recharts-ready. | Mots-clés : analytics, dashboard, time series |

#### Infrastructure
| Agent | Rôle | Déclenchement |
|---|---|---|
| `devops` | Dockerfiles multi-stage (non-root, healthcheck), docker-compose, CI/CD pipelines. | Si Dockerfile ou docker-compose absent |
| `infra-gcp` | Cloud Run, Cloud SQL, Artifact Registry, Workload Identity. Region `europe-west1`. | `type: perso` + demande cloud |
| `infra-azure` | Container Apps, Azure DB for PG, Key Vault, Managed Identity, Federated Credentials. | `type: clubmed` + demande cloud |
| `terraform-dev` | IaC GCP ou Azure depuis `.archipel/config/`. State distant (GCS/Azure Storage). | Si IaC requis |

#### Tests & Qualité
| Agent | Rôle | Déclenchement |
|---|---|---|
| `test-writer` | Jest + pytest, coverage ≥ 80%, fixtures PostgreSQL réelles (pas SQLite). | Après chaque milestone |
| `e2e-validator` | Smoke tests Playwright sur l'URL déployée. PASS/FAIL + screenshots. | Étape 4 — validation finale |
| `perf-tester` | k6 : smoke / average load / stress / spike. Seuils p95 < 500ms. | Endpoints à fort volume |
| `contract-tester` | schemathesis + openapi-typescript. Détecte les breaking changes API. | Après test-writer |

#### Review (5 dimensions)
| Agent | Rôle |
|---|---|
| `review-security` | Secrets, injections SQL/XSS, auth manquante, CORS, PII dans les logs |
| `review-architecture` | SoC, Repository pattern, typage TypeScript/Pydantic, Server Components |
| `review-performance` | N+1, pagination manquante, index absents, await séquentiel |
| `review-maintainability` | Fonctions trop longues, nommage obscur, duplication |
| `review-resilience` | Gestion d'erreurs, timeouts APIs tierces, cas limites, états UI vides |

#### Observabilité & Documentation
| Agent | Rôle | Déclenchement |
|---|---|---|
| `monitoring-dev` | OpenTelemetry : traces FastAPI + Next.js. Sentry (perso) ou Azure Monitor (clubmed). `/health` enrichi. | Une fois, post-milestones |
| `doc-writer` | OpenAPI enrichi (descriptions, exemples), CHANGELOG Keep a Changelog, ADR Markdown. | Après monitoring-dev |

#### Intelligence
| Agent | Rôle | Déclenchement |
|---|---|---|
| `kaizen` | Analyse les builds terminés, détecte les patterns d'amélioration. Observation uniquement. | Après build stable |
| `cost-analyzer` | Coût tokens Claude (cache/input/output), coût cloud GCP/Azure estimé par build. | Fin de chaque build |

---

## Gouvernance — Hooks Claude Code

Les hooks sont exécutés par le **harness Claude Code**, pas par Claude. Ils sont **déterministes à 100%** — aucun agent ne peut les contourner.

```mermaid
flowchart LR
    subgraph LIFECYCLE["Cycle de vie Claude Code"]
        SS["SessionStart"]
        UPE["UserPromptExpansion"]
        PTU["PreToolUse"]
        POTU["PostToolUse"]
        POTUF["PostToolUseFailure"]
        PTB["PostToolBatch"]
        SAS["SubagentStart"]
        SASP["SubagentStop"]
        ST["Stop / StopFailure"]
        TI["TeammateIdle"]
        PC["PreCompact / PostCompact"]
        SE["SessionEnd"]
        WC["WorktreeCreate / Remove"]
    end

    subgraph HOOKS["Hooks Archipel"]
        H1["on-session-start.sh\nContexte projet + build-state + leçons"]
        H2["on-slash-command.sh\nRedirige /build et /feature vers l'orchestrateur"]
        H3["on-bash.sh\nBloque : force push, rm -rf, DROP SQL, docker down -v"]
        H4["on-read-sensitive.sh\nBloque lecture .env *.pem *.key par les sous-agents"]
        H5["on-write.sh\nLint/format auto, protège components/ui/"]
        H6["on-post-bash.sh\nAudit log des ops impactantes"]
        H7["on-tool-failure.sh\nCapture et alerte sur tout échec d'outil"]
        H8["on-post-tool-batch.sh\nAlerte si >20% d'échecs dans un batch parallèle"]
        H9["on-subagent-start.sh\nEnregistre le contrat de scope de l'agent"]
        H10["on-subagent-stop.sh\nVérifie livrables + scope pour tous les agents"]
        H11["on-stop.sh\nTests finaux, résumé structuré, StopFailure diagnostic"]
        H12["on-teammate-idle.sh\nCheckpoint build-state entre les turns"]
        H13["on-pre-compact.sh\nInjecte état de gouvernance avant compression"]
        H14["on-post-compact.sh\nRé-injecte après compression"]
        H15["on-session-end.sh\nLog dans tasks/session-log.md"]
        H16["on-worktree.sh\nTrace création/suppression des worktrees"]
    end

    SS --> H1
    UPE --> H2
    PTU --> H3
    PTU --> H4
    POTU --> H5
    POTU --> H6
    POTUF --> H7
    PTB --> H8
    SAS --> H9
    SASP --> H10
    ST --> H11
    TI --> H12
    PC --> H13
    PC --> H14
    SE --> H15
    WC --> H16

    style H3 fill:#5f1e1e,color:#fff
    style H4 fill:#5f1e1e,color:#fff
    style H7 fill:#5f1e1e,color:#fff
    style H8 fill:#5f3d00,color:#fff
    style H10 fill:#1e3a5f,color:#fff
```

### Gates bloquants — `exit 2`, opération annulée

```mermaid
flowchart LR
    B1["🔒 git push --force\nsur main/master"] --> X1["exit 2"]
    B2["🔍 Secrets détectés\npar gitleaks"] --> X2["exit 2"]
    B3["🗄️ docker compose down -v\nsuppression volumes DB"] --> X3["exit 2"]
    B4["⚠️ DROP TABLE / DROP COLUMN\nen SQL direct"] --> X4["exit 2"]
    B5["🔐 Lecture .env / *.pem\npar un sous-agent"] --> X5["exit 2"]
    B6["🤖 architect terminé\nsans IMPL-*.md"] --> X6["exit 2"]
    B7["🎨 creative-director\nsans CREATIVE-BRIEF.md"] --> X7["exit 2"]
    B8["🎨 design-system\nsans DESIGN-SYSTEM.md"] --> X8["exit 2"]
    B9["🎨 ui-designer\nsans UI-SPECS.md ≥ 50 lignes"] --> X9["exit 2"]

    style B1 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B2 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B3 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B4 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B5 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B6 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B7 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B8 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style B9 fill:#5f1e1e,color:#ffcccc,stroke:#c0392b
    style X1 fill:#c0392b,color:#fff,stroke:#922b21
    style X2 fill:#c0392b,color:#fff,stroke:#922b21
    style X3 fill:#c0392b,color:#fff,stroke:#922b21
    style X4 fill:#c0392b,color:#fff,stroke:#922b21
    style X5 fill:#c0392b,color:#fff,stroke:#922b21
    style X6 fill:#c0392b,color:#fff,stroke:#922b21
    style X7 fill:#c0392b,color:#fff,stroke:#922b21
    style X8 fill:#c0392b,color:#fff,stroke:#922b21
    style X9 fill:#c0392b,color:#fff,stroke:#922b21
```

### Avertissements — confirmation ou contexte injecté

```mermaid
flowchart LR
    W1["⚠️ rm -rf\nhors build/cache"] --> A1["permissionDecision: ask\non-bash.sh"]
    W2["⚠️ alembic downgrade"] --> A2["permissionDecision: ask\non-bash.sh"]
    W3["💬 Migration Alembic\ncontient DROP"] --> A3["contexte injecté\non-write.sh"]
    W4["💬 Modification\ncomponents/ui/ shadcn"] --> A4["contexte injecté\non-write.sh"]
    W5["💬 coverage < 80%\naprès test-writer"] --> A5["contexte injecté\non-subagent-stop.sh"]
    W6["💬 Scope violation\nagent hors périmètre"] --> A6["contexte injecté\non-subagent-stop.sh"]
    W7["💬 PostToolBatch\n> 20% d'échecs"] --> A7["contexte injecté\non-post-tool-batch.sh"]

    style W1 fill:#7a5200,color:#ffe0a0,stroke:#e67e00
    style W2 fill:#7a5200,color:#ffe0a0,stroke:#e67e00
    style W3 fill:#4a4a00,color:#ffff99,stroke:#aaaa00
    style W4 fill:#4a4a00,color:#ffff99,stroke:#aaaa00
    style W5 fill:#4a4a00,color:#ffff99,stroke:#aaaa00
    style W6 fill:#4a4a00,color:#ffff99,stroke:#aaaa00
    style W7 fill:#4a4a00,color:#ffff99,stroke:#aaaa00
    style A1 fill:#5f3d00,color:#ffe0a0,stroke:#e67e00
    style A2 fill:#5f3d00,color:#ffe0a0,stroke:#e67e00
    style A3 fill:#3d3d00,color:#ffff99,stroke:#aaaa00
    style A4 fill:#3d3d00,color:#ffff99,stroke:#aaaa00
    style A5 fill:#3d3d00,color:#ffff99,stroke:#aaaa00
    style A6 fill:#3d3d00,color:#ffff99,stroke:#aaaa00
    style A7 fill:#3d3d00,color:#ffff99,stroke:#aaaa00
```

---

## Dual-deploy

```mermaid
flowchart TD
    SHIP["/ship"] --> READ["Lire .archipel/project.json"]

    READ --> PERSO{"type: perso ?"}

    PERSO -->|oui| GH["GitHub Actions"]
    PERSO -->|non| GL["GitLab CI"]

    GH --> GCP["GCP Cloud Run\n→ prod direct"]
    GL --> AZURE["Azure Container Apps\n→ staging"]
    AZURE --> VALID["Validation manuelle"]
    VALID --> PROD["→ prod"]

    style GCP fill:#1e5f1e,color:#fff
    style PROD fill:#1e5f1e,color:#fff
    style VALID fill:#5f3d00,color:#fff
```

| Config | perso | clubmed |
|---|---|---|
| Git remote | GitHub | GitLab |
| CI/CD | GitHub Actions | GitLab CI |
| Cloud | GCP | Azure |
| Strategy | Direct → prod | Staging → validation → prod |
| PostgreSQL | Cloud SQL | Azure Database for PG |

---

## Stack générée

```mermaid
graph TB
    subgraph MONOREPO["Monorepo Archipel"]
        subgraph WEB["apps/web/"]
            N["Next.js 16\nApp Router\nTypeScript strict\nServer Components first"]
        end
        subgraph API["apps/api/"]
            F["FastAPI\nPython 3.12+\nPydantic v2\nAsync partout"]
        end
        subgraph DB["shared/db/"]
            PR["Prisma\nschema.prisma\nmigrate dev"]
            AL["Alembic\nenv.py async\nasyncpg"]
        end
        subgraph WK["workers/"]
            BW["BaseWorker\nABC async"]
        end
    end

    N <-->|"REST / Server Actions"| F
    F <--> AL
    N <--> PR
    AL <--> PG[("PostgreSQL")]
    PR <--> PG

    style WEB fill:#1e3a5f,color:#fff,stroke:#2d6099
    style API fill:#2d4a1e,color:#fff,stroke:#4a7c35
    style DB fill:#4a2d1e,color:#fff,stroke:#7c4a35
```

---

## Self-improvement

Archipel apprend de ses erreurs. Chaque build alimente un journal de leçons réinjecté au démarrage de chaque session.

```mermaid
flowchart LR
    BUILD["Build d'un projet"] -->|erreur rencontrée| LESSONS["tasks/lessons.md\nFormat : date, contexte,\nerreur, correction, règle"]
    LESSONS -->|SessionStart hook| CONTEXT["Contexte injecté\nau démarrage suivant"]
    CONTEXT -->|agent évite l'erreur| BUILD

    BUILD -->|fin de session| LOG["tasks/session-log.md\nAction, livrable, résultat,\nprochaine étape"]

    style LESSONS fill:#4a2d1e,color:#fff
    style LOG fill:#2d2d2d,color:#fff
```

---

## Structure du repo

```
archipel/
├── .archipel/
│   ├── project.json          # Config projet actif (généré par /bootstrap)
│   ├── config/
│   │   ├── gcp.yml           # Template deploy perso
│   │   └── azure.yml         # Template deploy clubmed
│   └── templates/            # Templates réutilisables (Trident, etc.)
├── .claude/
│   ├── agents/               # 38 agents spécialisés
│   ├── commands/             # Slash commands (/spec, /feature, /ship…)
│   ├── hooks/                # 16 scripts de gouvernance
│   └── settings.json         # Mapping events → hooks
├── apps/
│   ├── api/                  # FastAPI scaffold
│   └── web/                  # Next.js scaffold
├── ci/
│   ├── github-actions/       # Pipeline perso
│   └── gitlab-ci/            # Pipeline clubmed
├── shared/db/
│   ├── alembic/              # Migrations Python
│   └── prisma/               # Schema + migrations TS
├── skills/                   # Conventions par domaine
├── tasks/
│   ├── lessons.md            # Journal d'apprentissage
│   └── session-log.md        # Log des sessions
└── workers/                  # Jobs async Python
```

---

## Démarrage rapide

```bash
# 1. Cloner la factory
git clone https://github.com/Nicolas78240/archipel
cd archipel

# 2. Bootstrapper un nouveau projet
# Dans Claude Code :
/bootstrap

# 3. Lancer le pipeline
/discover       # Valider l'idée
/spec           # PRD + tickets Jira
/design         # Flows + composants
/feature        # Code complet
/review         # Audit 5 dimensions
/qa             # Validation finale
/ship           # Deploy
```

---

## Qualité

Audit `2026-05-31` — **8,3 / 10**

| Dimension | Score |
|---|---|
| Sécurité | 9,5/10 — 0 secret, 0 CVE, trivy propre |
| Tests | 8,5/10 — coverage API 91% |
| Architecture | 9,0/10 — stack async cohérente |
| CI/CD | 9,0/10 — gitleaks + coverage enforced |
| Maintenabilité | 9,0/10 — CLAUDE.md 147 lignes, hooks documentés |

---

*Archipel — forge de Nicolas Caussin*

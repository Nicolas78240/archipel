# Archipel — Software Factory

> Pipeline de développement AI-first pour side projects personnels et projets Club Med.
> Orchestré par Claude Code — zéro revue humaine entre les étapes.

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

```mermaid
flowchart TD
    USER["👤 Nicolas"] --> BO

    subgraph PIPELINE["/feature — Séquence d'exécution"]
        BO["build-orchestrator\nOrchestre tout, ne code pas"] --> ARCH
        ARCH["architect\n→ IMPL-*.md"] --> DEV

        subgraph DEV_PARALLEL["Développement parallèle"]
            NX["nextjs-dev\n→ apps/web/"]
            FA["fastapi-dev\n→ apps/api/"]
            DB["db-dev\n→ shared/db/"]
        end
        DEV --> DEV_PARALLEL

        DEV_PARALLEL --> TW["test-writer\ncoverage ≥ 80%"]

        TW --> REVIEW_PARALLEL

        subgraph REVIEW_PARALLEL["Review parallèle — 5 dimensions"]
            RS["review-security"]
            RA["review-architecture"]
            RP["review-performance"]
            RM["review-maintainability"]
            RR["review-resilience"]
        end
    end

    subgraph DESIGN_PIPELINE["/design — Avant /feature"]
        CR["creative-director\n→ CREATIVE-BRIEF.md"]
        DSS["design-system\n→ DESIGN-SYSTEM.md"]
        UI["ui-designer\n→ UI-SPECS.md"]
        CR --> DSS --> UI
    end

    style BO fill:#1e3a5f,color:#fff
    style ARCH fill:#2d4a1e,color:#fff
    style TW fill:#4a2d1e,color:#fff
```

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

### Gates bloquants vs avertissements

```mermaid
flowchart LR
    subgraph BLOCK["🔴 Bloquants — exit 2"]
        B1["git push --force sur main/master"]
        B2["Lecture de .env / *.pem par un sous-agent"]
        B3["docker compose down -v"]
        B4["DROP TABLE / DROP COLUMN en SQL direct"]
        B5["architect sans IMPL-*.md"]
        B6["creative-director sans CREATIVE-BRIEF.md"]
        B7["design-system sans DESIGN-SYSTEM.md"]
        B8["ui-designer sans UI-SPECS.md ≥ 50 lignes"]
    end

    subgraph WARN["🟡 Avertissements — contexte injecté"]
        W1["rm -rf hors build/cache → permissionDecision: ask"]
        W2["alembic downgrade → permissionDecision: ask"]
        W3["Migration Alembic contient DROP"]
        W4["Modification de components/ui/ (shadcn)"]
        W5["coverage < 80% après test-writer"]
        W6["Scope violation : agent modifie hors son périmètre"]
        W7["PostToolBatch > 20% d'échecs"]
    end

    style BLOCK fill:#5f1e1e,color:#fff,stroke:#8b2222
    style WARN fill:#5f3d00,color:#fff,stroke:#8b5e00
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
│   ├── agents/               # 17 agents spécialisés
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

*Archipel — forge de Nicolas Girault*

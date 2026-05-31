# Architecture des Hooks — Archipel Software Factory

Les hooks sont des scripts shell exécutés **par le harness Claude Code**, pas par Claude.
C'est la différence fondamentale : ils sont **déterministes à 100%** — Claude ne peut pas les contourner.

---

## Principe fondamental

```mermaid
flowchart LR
    USER["👤 Nicolas\ntape /build --auto"]

    subgraph HARNESS["Harness Claude Code (déterministe)"]
        H1["UserPromptExpansion\nhook"]
        H2["on-slash-command.sh\nexécuté par le harness"]
    end

    subgraph CLAUDE["Claude (interprétation)"]
        C1["Agent(build-orchestrator)\ninvoqué directement"]
    end

    USER --> H1
    H1 --> H2
    H2 -->|"additionalContext injecté"| C1

    style HARNESS fill:#1e3a5f,color:#fff
    style CLAUDE fill:#2d4a1e,color:#fff
```

**Sans hook :** Claude lit `/build`, interprète les instructions, les exécute lui-même.
**Avec hook :** Le harness intercepte `/build`, injecte le contexte, Claude voit "invoque Agent(build-orchestrator)" comme instruction prioritaire.

---

## Les 6 hooks d'Archipel

```mermaid
flowchart TD
    subgraph EVENTS["Événements du cycle de vie"]

        E1["SessionStart\nDémarrage de session"]
        E2["UserPromptExpansion\nSlash command tapée"]
        E3["PreToolUse — Bash\nAvant exécution commande"]
        E4["PostToolUse — Write/Edit\nAprès écriture fichier"]
        E5["SubagentStop\nAgent sous-tâche terminé"]
        E6["Stop\nFin de session Claude"]

    end

    subgraph SCRIPTS["Scripts hooks (.claude/hooks/)"]

        S1["on-session-start.sh\n→ Injecter contexte projet\n→ État build en cours\n→ Dernières leçons"]
        S2["on-slash-command.sh\n→ /build → build-orchestrator\n→ /feature → build-orchestrator\n→ /ship → vérifier gates"]
        S3["on-bash.sh\n→ Bloquer git push --force/main\n→ Scan gitleaks\n→ Bloquer rm -rf\n→ Bloquer docker down -v\n→ Bloquer SQL DROP"]
        S4["on-write.sh\n→ Lint/format TS + Python\n→ Créer postcss.config.js\n→ Alerte migration DROP\n→ Protéger components/ui/\n→ Alerte secrets .env"]
        S5["on-subagent-stop.sh\n→ architect → IMPL-*.md ?\n→ creative-director → BRIEF ?\n→ design-system → DS.md ?\n→ ui-designer → UI-SPECS ?\n→ test-writer → coverage ≥ 80% ?"]
        S6["on-stop.sh\n→ Tests web + api\n→ Fichiers non committés"]

    end

    E1 --> S1
    E2 --> S2
    E3 --> S3
    E4 --> S4
    E5 --> S5
    E6 --> S6

    style S2 fill:#5f1e1e,color:#fff
    style S3 fill:#5f1e1e,color:#fff
    style S5 fill:#1e3a5f,color:#fff
```

---

## Flux complet d'un `/build --auto`

```mermaid
sequenceDiagram
    actor Nicolas
    participant H as Harness
    participant BO as build-orchestrator
    participant CD as creative-director
    participant DS as design-system
    participant UID as ui-designer
    participant ARCH as architect
    participant DEV as nextjs-dev + fastapi-dev
    participant TW as test-writer
    participant REV as 5 review agents

    Nicolas->>H: /build --auto
    Note over H: UserPromptExpansion hook<br/>on-slash-command.sh

    H->>BO: Agent(build-orchestrator)<br/>contexte injecté
    Note over H: DÉTERMINISTE — pas Claude

    BO->>CD: Agent(creative-director)
    CD-->>H: Termine
    Note over H: SubagentStop hook<br/>CREATIVE-BRIEF.md présent ? ✅

    BO->>DS: Agent(design-system)
    DS-->>H: Termine
    Note over H: SubagentStop hook<br/>DESIGN-SYSTEM.md ? ✅<br/>postcss.config.js ? (créé si absent)

    BO->>UID: Agent(ui-designer)
    UID-->>H: Termine
    Note over H: SubagentStop hook<br/>UI-SPECS.md ≥ 50 lignes ? ✅

    loop Pour chaque milestone M1→M6
        BO->>ARCH: Agent(architect)
        ARCH-->>H: Termine
        Note over H: SubagentStop hook<br/>IMPL-Mx.md présent ? ✅

        par Parallèle
            BO->>DEV: Agent(nextjs-dev)
        and
            BO->>DEV: Agent(fastapi-dev)
        end

        Note over H: PostToolUse sur chaque Write<br/>lint + format immédiat

        BO->>TW: Agent(test-writer)
        TW-->>H: Termine
        Note over H: SubagentStop hook<br/>coverage ≥ 80% ?

        par Parallèle
            BO->>REV: Agent(review-security)
        and
            BO->>REV: Agent(review-architecture)
        and
            BO->>REV: Agent(review-performance)
        and
            BO->>REV: Agent(review-maintainability)
        and
            BO->>REV: Agent(review-resilience)
        end
    end

    BO-->>Nicolas: 🏁 Build terminé
    Note over H: Stop hook<br/>tests finaux + uncommitted files
```

---

## Gates bloquants vs avertissements

```mermaid
flowchart TD
    subgraph BLOQUANTS["❌ Gates bloquants (exit 2)"]
        B1["git push --force sur main"]
        B2["Secrets détectés par gitleaks"]
        B3["docker compose down -v\nsuppression volumes DB"]
        B4["SQL DROP direct sans migration"]
        B5["IMPL-*.md absent après architect"]
        B6["CREATIVE-BRIEF.md absent après creative-director"]
        B7["DESIGN-SYSTEM.md absent après design-system"]
        B8["UI-SPECS.md absent ou < 50 lignes"]
    end

    subgraph AVERTISSEMENTS["⚠️ Avertissements (non bloquants)"]
        W1["Coverage < 80%\n→ note dans lessons.md"]
        W2["Migration contient DROP\n→ contexte injecté"]
        W3["Modification components/ui/\n→ contexte injecté"]
        W4["Fichiers non committés en fin de session"]
        W5["postcss.config.js absent\n→ créé automatiquement"]
    end

    style BLOQUANTS fill:#5f1e1e,color:#fff
    style AVERTISSEMENTS fill:#5f3d00,color:#fff
```

---

## Pourquoi les hooks, pas les instructions textuelles ?

```mermaid
flowchart LR
    subgraph AVANT["❌ Avant les hooks"]
        A1["Règle dans build.md :\n'Ne jamais modifier\ncomponents/ui/ directement'"]
        A2["Claude lit la règle"]
        A3["Claude décide de la suivre\nou pas"]
        A1 --> A2 --> A3
    end

    subgraph APRES["✅ Avec les hooks"]
        B1["Hook PostToolUse\nsur Write de components/ui/*"]
        B2["Harness exécute on-write.sh\nindépendamment de Claude"]
        B3["Contexte injecté :\n'RÈGLE VIOLÉE — utiliser features/'"]
        B1 --> B2 --> B3
    end

    style AVANT fill:#5f1e1e,color:#fff
    style APRES fill:#1e5f1e,color:#fff
```

**La différence :**
- Règle textuelle → Claude l'interprète → peut être contournée
- Hook → exécuté par le harness → **jamais contournable**

---

## Structure des fichiers

```
.claude/
  settings.json          ← Configuration des 6 hooks
  hooks/
    on-session-start.sh  ← SessionStart
    on-slash-command.sh  ← UserPromptExpansion (/build, /feature, /ship)
    on-bash.sh           ← PreToolUse Bash (commandes dangereuses)
    on-write.sh          ← PostToolUse Write|Edit (lint, sécurité, design)
    on-subagent-stop.sh  ← SubagentStop (gates livrables agents)
    on-stop.sh           ← Stop (tests finaux, uncommitted)
```

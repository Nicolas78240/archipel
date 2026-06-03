"use client";
import React, { useState, useEffect, useRef } from "react";

const MONITOR_URL = process.env.NEXT_PUBLIC_MONITOR_URL ?? "http://localhost:3999";

type StageId = "discover" | "spec" | "design" | "feature" | "review" | "qa" | "ship";
type EventType = "ok" | "blocked" | "warn" | "info" | "agent" | "write" | "success";

interface AgentDef { id: string; stage: StageId; layer: string; name: string; desc: string; }
interface Agent extends AgentDef { si: number; color: string; }
interface Stage { id: StageId; cmd: string; sym: string; color: string; }
interface Project { name: string; stage: StageId; color: string; type: "perso" | "clubmed"; cloud: string; sessions: number; hooks: number; desc: string; used: Set<string>; }
interface LiveEvent { id: number; ts: string; type: EventType; msg: string; dur: number | null; ag: string | null; hook?: string; rw: { from: StageId; to: StageId } | null; }
interface Rework { id: number; from: StageId; to: StageId; proj: string; ts: number; }
interface Notif { id: number; x: number; y: number; msg: string; c: string; rw: boolean; ts: number; }
interface TooltipState { agent: Agent; x: number; y: number; }
interface PoolEntry { msg: string; type: EventType; ag: string | null; hook?: string; rw: { from: StageId; to: StageId } | null; stages?: StageId[]; }
interface HookDef { id: string; event: string; name: string; desc: string; color: string; }
interface StarDef { cx: number; cy: number; r: number; op: number; }

const AGENT_DEFS: AgentDef[] = [
  { id:"build-orchestrator",    stage:"discover", layer:"Orchestration", name:"Build Orchestrator", desc:"Orchestre l'intégralité du build. Ne touche jamais au code. Délègue via IMPL-*.md." },
  { id:"architect",             stage:"spec",    layer:"Orchestration", name:"Architect",          desc:"Produit docs/IMPL-*.md — le plan technique consommé par tous les agents dev." },
  { id:"creative-director",     stage:"design",  layer:"Design",        name:"Creative Director",  desc:"Direction visuelle, palette, typographie → CREATIVE-BRIEF.md." },
  { id:"design-system",         stage:"design",  layer:"Design",        name:"Design System",      desc:"Tokens Tailwind, globals.css, composants métier → DESIGN-SYSTEM.md." },
  { id:"ui-designer",           stage:"design",  layer:"Design",        name:"UI Designer",        desc:"Specs composants ultra-précises, layout ASCII → UI-SPECS.md ≥ 50 lignes." },
  { id:"design-reviewer",       stage:"design",  layer:"Design",        name:"Design Reviewer",    desc:"Vérifie que le code frontend correspond aux specs pixel-perfect." },
  { id:"nextjs-dev",            stage:"feature", layer:"Frontend",      name:"Next.js Dev",        desc:"Next.js 16 App Router, Server Components, Server Actions. Patterns Vercel." },
  { id:"ios-dev",               stage:"feature", layer:"Frontend",      name:"iOS Dev",            desc:"Swift 5.9+ / SwiftUI / URLSession / MSAL Azure AD pour clubmed." },
  { id:"android-dev",           stage:"feature", layer:"Frontend",      name:"Android Dev",        desc:"Kotlin / Jetpack Compose / Retrofit / MSAL Android pour clubmed." },
  { id:"accessibility",         stage:"feature", layer:"Frontend",      name:"Accessibility",      desc:"Audit WCAG 2.1 AA : ARIA, contraste, navigation clavier, VoiceOver." },
  { id:"fastapi-dev",           stage:"feature", layer:"Backend",       name:"FastAPI Dev",        desc:"Routers → Services → Repositories. Async partout, Pydantic v2, ruff clean." },
  { id:"auth-dev",              stage:"feature", layer:"Backend",       name:"Auth Dev",           desc:"OAuth2, JWT, RBAC. Azure AD SSO (clubmed) / PyJWT (perso). next-auth." },
  { id:"websocket-dev",         stage:"feature", layer:"Backend",       name:"WebSocket Dev",      desc:"WebSocket FastAPI, ConnectionManager, SSE. Reconnexion React avec backoff." },
  { id:"worker-dev",            stage:"feature", layer:"Backend",       name:"Worker Dev",         desc:"Workers async héritant de BaseWorker. Redis BLPOP, DLQ, stateless + idempotent." },
  { id:"cache-dev",             stage:"feature", layer:"Backend",       name:"Cache Dev",          desc:"Redis async, cache-aside, stampede protection, revalidateTag Next.js." },
  { id:"integration-dev",       stage:"feature", layer:"Backend",       name:"Integration Dev",    desc:"Webhooks HMAC, idempotency keys, retry avec backoff, circuit breaker." },
  { id:"api-gateway-dev",       stage:"feature", layer:"Backend",       name:"API Gateway Dev",    desc:"Nginx rate limiting, Traefik labels, middlewares FastAPI (CORS, logging)." },
  { id:"db-dev",                stage:"feature", layer:"Data",          name:"DB Dev",             desc:"Modèles SQLAlchemy, migrations Alembic async, schéma Prisma, index." },
  { id:"dba",                   stage:"feature", layer:"Data",          name:"DBA",                desc:"Optimisation PostgreSQL : EXPLAIN ANALYZE, index CONCURRENTLY, N+1." },
  { id:"vector-db-dev",         stage:"feature", layer:"Data",          name:"Vector DB Dev",      desc:"pgvector : vector(1536), index HNSW/IVFFlat, RAG patterns, embeddings batch." },
  { id:"analytics-dev",         stage:"feature", layer:"Data",          name:"Analytics Dev",      desc:"CTEs, window functions, time series, requêtes Recharts-ready." },
  { id:"devops",                stage:"ship",    layer:"Infra",         name:"DevOps",             desc:"Dockerfiles multi-stage (non-root, healthcheck), docker-compose, CI/CD." },
  { id:"infra-gcp",             stage:"ship",    layer:"Infra",         name:"Infra GCP",          desc:"Cloud Run, Cloud SQL, Artifact Registry, Workload Identity. europe-west1." },
  { id:"infra-azure",           stage:"ship",    layer:"Infra",         name:"Infra Azure",        desc:"Container Apps, Azure DB for PG, Key Vault, Managed Identity." },
  { id:"terraform-dev",         stage:"ship",    layer:"Infra",         name:"Terraform Dev",      desc:"IaC GCP ou Azure depuis .archipel/config/. State distant GCS/Azure Storage." },
  { id:"test-writer",           stage:"feature", layer:"Tests",         name:"Test Writer",        desc:"Jest + pytest, coverage ≥ 80%, fixtures PostgreSQL réelles (pas SQLite)." },
  { id:"e2e-validator",         stage:"qa",      layer:"Tests",         name:"E2E Validator",      desc:"Smoke tests Playwright sur l'URL déployée. PASS/FAIL + screenshots." },
  { id:"perf-tester",           stage:"feature", layer:"Tests",         name:"Perf Tester",        desc:"k6 : smoke / average load / stress / spike. Seuils p95 < 500ms." },
  { id:"contract-tester",       stage:"feature", layer:"Tests",         name:"Contract Tester",    desc:"schemathesis + openapi-typescript. Détecte les breaking changes API." },
  { id:"review-security",       stage:"review",  layer:"Review",        name:"Security Review",    desc:"Secrets, injections SQL/XSS, auth manquante, CORS, PII dans les logs." },
  { id:"review-architecture",   stage:"review",  layer:"Review",        name:"Architecture",       desc:"SoC, Repository pattern, typage TypeScript/Pydantic, Server Components." },
  { id:"review-performance",    stage:"review",  layer:"Review",        name:"Performance",        desc:"N+1, pagination manquante, index absents, await séquentiel." },
  { id:"review-maintainability",stage:"review",  layer:"Review",        name:"Maintainability",    desc:"Fonctions trop longues, nommage obscur, duplication." },
  { id:"review-resilience",     stage:"review",  layer:"Review",        name:"Resilience",         desc:"Gestion d'erreurs, timeouts APIs tierces, cas limites, états UI vides." },
  { id:"monitoring-dev",        stage:"feature", layer:"Observability", name:"Monitoring Dev",     desc:"OpenTelemetry : traces FastAPI + Next.js. Sentry (perso) / Azure Monitor (clubmed)." },
  { id:"doc-writer",            stage:"feature", layer:"Observability", name:"Doc Writer",         desc:"OpenAPI enrichi (descriptions, exemples), CHANGELOG, ADR Markdown." },
  { id:"kaizen",                stage:"ship",    layer:"Intelligence",  name:"Kaizen",             desc:"Analyse les builds terminés, détecte les patterns d'amélioration. Observation uniquement." },
  { id:"cost-analyzer",         stage:"ship",    layer:"Intelligence",  name:"Cost Analyzer",      desc:"Coût tokens Claude (cache/input/output), coût cloud GCP/Azure estimé par build." },
];

const STAGES: Stage[] = [
  { id:"discover", cmd:"/discover", sym:"◈", color:"#4fd1c5" },
  { id:"spec",     cmd:"/spec",     sym:"◰", color:"#63b3ed" },
  { id:"design",   cmd:"/design",   sym:"✦", color:"#b794f4" },
  { id:"feature",  cmd:"/feature",  sym:"⚡", color:"#f6e05e" },
  { id:"review",   cmd:"/review",   sym:"◎", color:"#f6ad55" },
  { id:"qa",       cmd:"/qa",       sym:"◉", color:"#fc8181" },
  { id:"ship",     cmd:"/ship",     sym:"▲", color:"#68d391" },
];
const IDX: Record<string, number> = Object.fromEntries(STAGES.map((s, i) => [s.id, i]));
const AGENTS: Agent[] = AGENT_DEFS.map(a => { const si = IDX[a.stage] ?? 3; return { ...a, si, color: (STAGES[si] ?? STAGES[3])!.color }; });

const DEMO_PROJECTS: Project[] = [
  { name:"ErgWarrior",  stage:"review",  color:"#f6ad55", type:"perso",   cloud:"GCP",   sessions:23, hooks:341,
    desc:"iOS gamified BikeErg — Boss Fight / Ghost Race / RPG",
    used:new Set(["build-orchestrator","architect","creative-director","design-system","ui-designer","design-reviewer","ios-dev","accessibility","test-writer","perf-tester","contract-tester","review-security","review-architecture","review-performance","review-maintainability","review-resilience","infra-gcp","devops","monitoring-dev","doc-writer","cost-analyzer","kaizen"]) },
  { name:"PixFarm",     stage:"feature", color:"#f6e05e", type:"perso",   cloud:"GCP",   sessions:14, hooks:218,
    desc:"Next.js + FastAPI — Claude Code sessions as pixel art",
    used:new Set(["build-orchestrator","architect","nextjs-dev","fastapi-dev","db-dev","dba","cache-dev","websocket-dev","test-writer","e2e-validator","contract-tester","review-security","review-architecture","review-performance","review-maintainability","review-resilience","infra-gcp","devops","monitoring-dev","doc-writer","cost-analyzer"]) },
  { name:"DesignHerd",  stage:"feature", color:"#63b3ed", type:"clubmed", cloud:"Azure", sessions:9,  hooks:127,
    desc:"Internal design QA — Jira bidirectional sync",
    used:new Set(["build-orchestrator","architect","creative-director","design-system","ui-designer","design-reviewer","nextjs-dev","fastapi-dev","db-dev","auth-dev","websocket-dev","integration-dev","test-writer","review-security","review-architecture","review-performance","review-maintainability","review-resilience","infra-azure","devops","terraform-dev","monitoring-dev","doc-writer","cost-analyzer"]) },
  { name:"DartFlow",    stage:"design",  color:"#4fd1c5", type:"perso",   cloud:"GCP",   sessions:4,  hooks:52,
    desc:"Darts training tracker — ErgWarrior sister app",
    used:new Set(["build-orchestrator","architect","creative-director","design-system","ui-designer","ios-dev","test-writer","review-security","review-architecture","review-maintainability","review-resilience","infra-gcp","devops","cost-analyzer"]) },
];

const HOOK_DEFS: HookDef[] = [
  { id:"on-session-start",   event:"SessionStart",          name:"session-start",   color:"#4fd1c5", desc:"Injecte le contexte build-state + lessons au démarrage. Alerte si fichiers non commités." },
  { id:"on-session-end",     event:"SessionEnd",            name:"session-end",     color:"#4fd1c5", desc:"Archive le résumé de session dans tasks/session-log.md." },
  { id:"on-bash",            event:"PreToolUse(Bash)",      name:"on-bash",         color:"#f6ad55", desc:"Gate: bloque git push --force, rm -rf, docker down -v, DROP TABLE, alembic downgrade." },
  { id:"on-write",           event:"PostToolUse(Write)",    name:"on-write",        color:"#b794f4", desc:"Lance eslint, ruff et prettier après chaque écriture de fichier." },
  { id:"on-subagent-start",  event:"SubagentStart",         name:"subagent-start",  color:"#63b3ed", desc:"Enregistre le contrat de scope de chaque agent avant qu'il commence." },
  { id:"on-subagent-stop",   event:"SubagentStop",          name:"subagent-stop",   color:"#63b3ed", desc:"Vérifie que l'agent n'a pas débordé de son scope. Gate: livrables obligatoires." },
  { id:"on-stop",            event:"Stop",                  name:"on-stop",         color:"#68d391", desc:"Vérifie tests, coverage et git status à la fin de chaque turn." },
  { id:"on-tool-failure",    event:"PostToolUseFailure",    name:"tool-failure",    color:"#fc8181", desc:"Capture tous les échecs de tool et alerte l'orchestrateur explicitement." },
  { id:"on-post-batch",      event:"PostToolBatch",         name:"post-batch",      color:"#f6ad55", desc:"Alerte si >20% des tool calls d'un batch ont échoué." },
  { id:"on-pre-compact",     event:"PreCompact",            name:"pre-compact",     color:"#4fd1c5", desc:"Injecte build-state + lessons dans le contexte avant compression." },
  { id:"on-post-compact",    event:"PostCompact",           name:"post-compact",    color:"#4fd1c5", desc:"Ré-injecte build-state après compression pour éviter la dérive." },
  { id:"on-read-sensitive",  event:"PreToolUse(Read)",      name:"read-sensitive",  color:"#fc8181", desc:"Bloque la lecture des fichiers sensibles (.env, *.pem, credentials.*)." },
  { id:"on-worktree",        event:"WorktreeCreate/Remove", name:"on-worktree",     color:"#b794f4", desc:"Log les créations/suppressions de worktrees git isolés." },
  { id:"on-teammate-idle",   event:"TeammateIdle",          name:"teammate-idle",   color:"#f6ad55", desc:"Checkpoint entre turns — alerte si un build est en cours ou interrompu." },
  { id:"on-teammate-stop",   event:"StopFailure",           name:"teammate-stop",   color:"#fc8181", desc:"Diagnostic immédiat en cas de turn terminé en erreur." },
  { id:"on-prompt-submit",   event:"UserPromptSubmit",      name:"prompt-submit",   color:"#68d391", desc:"Injecte la date courante + contexte sécurité à chaque message utilisateur." },
];

const VW = 1200, VH = 300, NY = 155, NR = 24;
const sx = (i: number) => 94 + i * 169;
const fwdPath = (i: number) => { const x1 = sx(i) + NR, x2 = sx(i + 1) - NR, mx = (x1 + x2) / 2; return `M${x1},${NY} C${mx},${NY - 11} ${mx},${NY + 11} ${x2},${NY}`; };
const rwPath = (fi: number, ti: number, lift: number) => { const x1 = sx(fi) - NR, x2 = sx(ti) + NR; return `M${x1},${NY} C${x1},${NY - lift} ${x2},${NY - lift} ${x2},${NY}`; };
const STARS: StarDef[] = Array.from({ length: 50 }, (_, i) => ({ cx: ((i * 139 + 37) % 1180) + 10, cy: ((i * 197 + 83) % 270) + 5, r: i % 4 === 0 ? 1.0 : i % 2 === 0 ? 0.6 : 0.35, op: 0.025 + (i % 5) * 0.016 }));

const EC: Record<string, string> = { ok:"#68d391", blocked:"#fc8181", warn:"#f6ad55", info:"#4fd1c5", agent:"#63b3ed", write:"#b794f4", success:"#68d391" };
const RWC = "#ff9944";
const rnd = <T,>(a: T[]): T => a[Math.floor(Math.random() * a.length)] as T;
const ts = () => { const d = new Date(); return [d.getHours(), d.getMinutes(), d.getSeconds()].map(n => String(n).padStart(2, "0")).join(":"); };
let uid = 0;

const POOL: PoolEntry[] = [
  // ── Orchestration ────────────────────────────────────────────────
  { msg:"build-orchestrator → phase 1/4 agents lancés",          type:"agent",   ag:"build-orchestrator",     rw:null },
  { msg:"architect → IMPL-m1-auth.md (48 lignes)",               type:"agent",   ag:"architect",              rw:null },
  { msg:"architect → IMPL-m2-dashboard.md (91 lignes)",          type:"agent",   ag:"architect",              rw:null },
  { msg:"build-orchestrator → 3 agents parallèles (5 slots libres)", type:"info", ag:"build-orchestrator",    rw:null },
  // ── Hooks système ────────────────────────────────────────────────
  { msg:"contexte chargé, 12 fichiers non commités",               type:"info",    ag:null, hook:"on-session-start",  rw:null },
  { msg:"git push main → scan gitleaks OK",                        type:"ok",      ag:null, hook:"on-bash",            rw:null },
  { msg:"GATE: git push --force main → exit 2",                    type:"blocked", ag:null, hook:"on-bash",            rw:null },
  { msg:"eslint apps/web/src/app/dashboard/page.tsx",              type:"write",   ag:null, hook:"on-write",           rw:null },
  { msg:"ruff check apps/api/routers/projects.py",                 type:"write",   ag:null, hook:"on-write",           rw:null },
  { msg:"prettier src/components/KanbanBoard.tsx",                 type:"write",   ag:null, hook:"on-write",           rw:null },
  { msg:"tests web OK · git: 4 fichiers non commités",             type:"success", ag:null, hook:"on-stop",            rw:null },
  { msg:"tests API FAILED · coverage 71% < 80%",                   type:"warn",    ag:null, hook:"on-stop",            rw:null },
  { msg:"scope OK: nextjs-dev → apps/web/",                        type:"ok",      ag:"nextjs-dev",  hook:"on-subagent-stop", rw:null },
  { msg:"WARN: fastapi-dev a modifié apps/web/",                   type:"warn",    ag:"fastapi-dev", hook:"on-subagent-stop", rw:null },
  { msg:"subagent architect démarré — scope: docs/",               type:"info",    ag:"architect",   hook:"on-subagent-start",rw:null },
  { msg:"Read: fichier absent apps/api/.env",                      type:"blocked", ag:null, hook:"on-tool-failure",    rw:null },
  { msg:"build-state.json injecté dans contexte",                  type:"info",    ag:null, hook:"on-pre-compact",     rw:null },
  { msg:"batch: 4/18 tool calls échoués — seuil 20% dépassé",      type:"warn",    ag:null, hook:"on-post-batch",      rw:null },
  { msg:"lecture .env bloquée — fichier sensible",                  type:"blocked", ag:null, hook:"on-read-sensitive",  rw:null },
  { msg:"session archivée → tasks/session-log.md",                  type:"success", ag:null, hook:"on-session-end",     rw:null },
  // ── Frontend ─────────────────────────────────────────────────────
  { msg:"nextjs-dev → KanbanBoard.tsx Server Component (312 lignes)", type:"agent", ag:"nextjs-dev",            rw:null },
  { msg:"nextjs-dev → Server Action createProject() implémentée",  type:"ok",      ag:"nextjs-dev",             rw:null },
  { msg:"nextjs-dev → page.tsx: generateMetadata + suspense OK",   type:"ok",      ag:"nextjs-dev",             rw:null },
  { msg:"design-system → tailwind.config.ts tokens Trident générés", type:"agent", ag:"design-system",          rw:null },
  { msg:"ui-designer → UI-SPECS.md 74 lignes — gate validé",       type:"ok",      ag:"ui-designer",            rw:null },
  { msg:"accessibility → audit WCAG 2.1 AA — 3 violations aria-label", type:"warn", ag:"accessibility",         rw:null },
  { msg:"ios-dev → BossFightView.swift compilé — 0 warnings",      type:"ok",      ag:"ios-dev",                rw:null },
  // ── Backend ──────────────────────────────────────────────────────
  { msg:"fastapi-dev → POST /api/v1/projects — Pydantic v2 OK",    type:"agent",   ag:"fastapi-dev",            rw:null },
  { msg:"fastapi-dev → Repository pattern — 3 endpoints async",    type:"ok",      ag:"fastapi-dev",            rw:null },
  { msg:"auth-dev → JWT middleware + RBAC roles:admin,member",      type:"agent",   ag:"auth-dev",               rw:null },
  { msg:"websocket-dev → ConnectionManager broadcast OK",           type:"ok",      ag:"websocket-dev",          rw:null },
  { msg:"cache-dev → Redis cache-aside TTL 300s — stampede prot.",  type:"ok",      ag:"cache-dev",              rw:null },
  { msg:"worker-dev → SyncWorker.execute() idempotent — DLQ OK",   type:"ok",      ag:"worker-dev",             rw:null },
  // ── Data ─────────────────────────────────────────────────────────
  { msg:"db-dev → migration 0014_add_project_stages.py générée",   type:"agent",   ag:"db-dev",                 rw:null },
  { msg:"db-dev → index CONCURRENTLY project_id, created_at",      type:"ok",      ag:"db-dev",                 rw:null },
  { msg:"dba → EXPLAIN ANALYZE — seq scan détecté sur sessions(512k)", type:"warn", ag:"dba",                   rw:null },
  { msg:"dba → index idx_sessions_user_date — p95 42ms → 8ms",     type:"ok",      ag:"dba",                    rw:null },
  // ── Tests ────────────────────────────────────────────────────────
  { msg:"test-writer → jest: 47 tests — coverage 86%",             type:"ok",      ag:"test-writer",            rw:null },
  { msg:"test-writer → pytest: 31 tests — coverage 82%",           type:"ok",      ag:"test-writer",            rw:null },
  { msg:"test-writer → coverage 74% < 80% — gate KO",              type:"warn",    ag:"test-writer",            rw:null },
  { msg:"e2e-validator → Playwright 24/24 smoke tests PASS",        type:"ok",      ag:"e2e-validator",          rw:null },
  { msg:"perf-tester → k6 stress: p95=312ms p99=780ms — OK",       type:"ok",      ag:"perf-tester",            rw:null },
  { msg:"contract-tester → schemathesis: 0 breaking changes",       type:"ok",      ag:"contract-tester",        rw:null },
  // ── Review ───────────────────────────────────────────────────────
  { msg:"review-security → 0 CVE critique — gitleaks clean",        type:"ok",      ag:"review-security",        rw:null },
  { msg:"review-security → PII dans logs: user.email logué → REWORK", type:"blocked", ag:"review-security",     rw:{ from:"review", to:"spec" } },
  { msg:"review-architecture → couplage fort UI/DB → REWORK",       type:"blocked", ag:"review-architecture",   rw:{ from:"review", to:"feature" } },
  { msg:"review-architecture → Repository pattern OK — merge GO",   type:"ok",      ag:"review-architecture",   rw:null },
  { msg:"review-performance → N+1 détecté sur /projects/:id",       type:"warn",    ag:"review-performance",     rw:null },
  { msg:"review-performance → pagination manquante sur /sessions",  type:"warn",    ag:"review-performance",     rw:null },
  { msg:"review-maintainability → OK — 0 finding critique",         type:"ok",      ag:"review-maintainability", rw:null },
  { msg:"review-resilience → timeout manquant httpx externe → REWORK", type:"blocked", ag:"review-resilience",  rw:{ from:"review", to:"feature" } },
  // ── Infra / Ship ─────────────────────────────────────────────────
  { msg:"devops → Dockerfile multi-stage — image 148MB non-root",   type:"ok",      ag:"devops",                 rw:null },
  { msg:"infra-gcp → Cloud Run deployed — europe-west1",            type:"ok",      ag:"infra-gcp",              rw:null },
  { msg:"infra-azure → Container App provisioned — francecentral",  type:"ok",      ag:"infra-azure",            rw:null },
  { msg:"terraform-dev → plan: +3 ~1 -0 ressources",                type:"ok",      ag:"terraform-dev",          rw:null },
  // ── Observabilité / Intelligence ─────────────────────────────────
  { msg:"monitoring-dev → OpenTelemetry traces FastAPI + Next.js",  type:"ok",      ag:"monitoring-dev",         rw:null },
  { msg:"doc-writer → CHANGELOG.md M3 — 8 endpoints documentés",   type:"ok",      ag:"doc-writer",             rw:null },
  { msg:"cost-analyzer → $0.23 tokens · $3.10 cloud · ROI x12",    type:"ok",      ag:"cost-analyzer",          rw:null },
  { msg:"kaizen → pattern détecté: N+1 récurrent sur /api/users",   type:"info",    ag:"kaizen",                 rw:null },
];

function Tooltip({ agent, x, y }: { agent: Agent; x: number; y: number }) {
  return (
    <div style={{position:"fixed",left:Math.min(x,window.innerWidth-280),top:Math.max(y-80,8),zIndex:9999,background:"rgba(4,8,18,0.98)",border:`1px solid ${agent.color}60`,borderRadius:6,padding:"9px 12px",pointerEvents:"none",maxWidth:270,boxShadow:`0 4px 24px rgba(0,0,0,0.7),0 0 12px ${agent.color}22`}}>
      <div style={{fontSize:9,color:agent.color,fontFamily:"'JetBrains Mono',monospace",marginBottom:4,letterSpacing:"0.06em",fontWeight:700}}>{agent.name}</div>
      <div style={{fontSize:8,color:"#7a9ab0",fontFamily:"'JetBrains Mono',monospace",lineHeight:1.55}}>{agent.desc}</div>
      <div style={{display:"flex",gap:6,marginTop:6}}>
        <span style={{fontSize:7,color:"#3a5060",fontFamily:"'JetBrains Mono',monospace",background:"rgba(255,255,255,0.04)",padding:"1px 5px",borderRadius:2}}>{agent.layer}</span>
        <span style={{fontSize:7,color:"#3a5060",fontFamily:"'JetBrains Mono',monospace",background:"rgba(255,255,255,0.04)",padding:"1px 5px",borderRadius:2}}>GARAGE</span>
      </div>
    </div>
  );
}

function AgentPill({ agent, state, firing }: { agent: Agent; state: string; firing: boolean }) {
  let bg: string, bd: string, tx: string, ld: string, gs: string;
  if (firing) {
    // État FIRING : très visible, fond coloré + glow fort
    bg=`${agent.color}28`; bd=agent.color; tx=agent.color; ld=agent.color; gs=`0 0 10px ${agent.color}99`;
  } else if (state === "ACTIVE") {
    bg=`${agent.color}12`; bd=`${agent.color}55`; tx=`${agent.color}cc`; ld=`${agent.color}88`; gs=`0 0 4px ${agent.color}44`;
  } else if (state === "NEXT") {
    bg="rgba(255,255,255,0.03)"; bd="rgba(255,255,255,0.12)"; tx="#8aaac0"; ld="#4a6070"; gs="none";
  } else if (state === "DONE") {
    bg="transparent"; bd="rgba(255,255,255,0.05)"; tx="#4a6070"; ld="#2a3c4c"; gs="none";
  } else {
    bg="transparent"; bd="rgba(255,255,255,0.03)"; tx="#2a3c4c"; ld="#1a2838"; gs="none";
  }
  return (
    <div style={{display:"flex",alignItems:"center",gap:4,padding:firing?"3px 7px":"2px 6px",borderRadius:3,marginBottom:2,background:bg,border:`1px solid ${bd}`,transition:"all 0.25s",boxShadow:firing?`0 0 12px ${agent.color}33`:"none"}}>
      <div style={{width:firing?5:4,height:firing?5:4,borderRadius:"50%",flexShrink:0,background:firing?ld:"transparent",border:firing?"none":`1px solid ${ld}`,boxShadow:gs,transition:"all 0.25s"}}/>
      <span style={{fontSize:firing?8:7.5,color:tx,fontFamily:"'JetBrains Mono',monospace",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",flex:1,fontWeight:firing?700:400}}>{agent.name}</span>
      {firing && <span style={{fontSize:6.5,color:agent.color,flexShrink:0,animation:"blink 0.8s step-end infinite"}}>▶</span>}
      {state === "DONE" && !firing && <span style={{fontSize:6,color:"#3a5468",flexShrink:0}}>✓</span>}
    </div>
  );
}

function HookTooltip({ hook, x, y }: { hook: HookDef; x: number; y: number }) {
  return (
    <div style={{position:"fixed",left:Math.min(x,window.innerWidth-290),top:Math.max(y-80,8),zIndex:9999,background:"rgba(4,8,18,0.98)",border:`1px solid ${hook.color}50`,borderRadius:6,padding:"9px 12px",pointerEvents:"none",maxWidth:280,boxShadow:`0 4px 24px rgba(0,0,0,0.8),0 0 14px ${hook.color}18`}}>
      <div style={{fontSize:8,color:hook.color,fontFamily:"'JetBrains Mono',monospace",marginBottom:3,letterSpacing:"0.06em",fontWeight:700}}>{hook.name}</div>
      <div style={{fontSize:7,color:"#8ab0c8",fontFamily:"'JetBrains Mono',monospace",marginBottom:5,opacity:0.7}}>{hook.event}</div>
      <div style={{fontSize:7.5,color:"#b0c8d8",fontFamily:"'JetBrains Mono',monospace",lineHeight:1.6}}>{hook.desc}</div>
    </div>
  );
}

function AgentsSection({ proj, curSi, firing, firingHooks, setTooltip }: { proj: Project; curSi: number; firing: Set<string>; firingHooks: Set<string>; setTooltip: (t: TooltipState | null) => void }) {
  const used   = AGENTS.filter(a => proj.used.has(a.id));
  const garage = AGENTS.filter(a => !proj.used.has(a.id));
  const byStage = STAGES.map(s => used.filter(a => a.stage === s.id));
  const agState = (a: Agent) => a.si < curSi ? "DONE" : a.si === curSi ? "ACTIVE" : a.si === curSi + 1 ? "NEXT" : "PENDING";
  const [hookTooltip, setHookTooltip] = React.useState<{ hook: HookDef; x: number; y: number } | null>(null);

  const firingAgents = AGENTS.filter(a => firing.has(a.id));

  return (
    <div style={{flex:1,overflowY:"auto",display:"flex",flexDirection:"column"}}>

      {/* ── Bandeau agents en cours ── */}
      {firingAgents.length > 0 && (
        <div style={{padding:"6px 14px",background:"rgba(99,179,237,0.07)",borderBottom:"1px solid rgba(99,179,237,0.20)",display:"flex",alignItems:"center",gap:8,flexWrap:"wrap"}}>
          <span style={{fontSize:7,color:"#63b3ed",fontFamily:"'JetBrains Mono',monospace",letterSpacing:"0.1em",fontWeight:700,flexShrink:0}}>▶ EN COURS</span>
          {firingAgents.map(a => (
            <div key={a.id} style={{display:"flex",alignItems:"center",gap:5,padding:"2px 8px",borderRadius:3,background:`${a.color}20`,border:`1px solid ${a.color}`,boxShadow:`0 0 8px ${a.color}44`}}>
              <div style={{width:5,height:5,borderRadius:"50%",background:a.color,boxShadow:`0 0 6px ${a.color}`,animation:"blink 0.8s step-end infinite"}}/>
              <span style={{fontSize:8,color:a.color,fontFamily:"'JetBrains Mono',monospace",fontWeight:700}}>{a.name}</span>
              <span style={{fontSize:6.5,color:`${a.color}88`,fontFamily:"'JetBrains Mono',monospace"}}>{a.layer}</span>
            </div>
          ))}
        </div>
      )}

      {/* ── Agents assignés ── */}
      <div style={{padding:"7px 14px 5px",borderBottom:"1px solid rgba(255,255,255,0.06)"}}>
        <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:6}}>
          <span style={{fontSize:7.5,color:"#7ab8d8",letterSpacing:"0.1em",fontFamily:"'JetBrains Mono',monospace",fontWeight:600}}>AGENTS ASSIGNÉS · {used.length}</span>
          <div style={{display:"flex",gap:10}}>
            {([ ["ACTIVE", STAGES[curSi]?.color ?? "#fff"], ["NEXT", "#6a8aaa"], ["DONE", "#4a6880"] ] as [string, string][]).map(([l, c]) => (
              <span key={l} style={{display:"flex",alignItems:"center",gap:3,fontSize:6.5,color:"#5a7a90",fontFamily:"'JetBrains Mono',monospace"}}>
                <span style={{display:"inline-block",width:4,height:4,borderRadius:"50%",background:c}}/>
                {l.toLowerCase()}
              </span>
            ))}
          </div>
        </div>
        <div style={{display:"grid",gridTemplateColumns:"repeat(7,1fr)",gap:5}}>
          {STAGES.map((st, i) => {
            const ags = byStage[i] ?? [], cur = i === curSi, done = i < curSi;
            return (
              <div key={st.id} style={{padding:"5px 7px",borderRadius:3,border:`1px solid ${cur ? st.color + "55" : done ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.04)"}`,background:cur ? `${st.color}0d` : done ? "rgba(255,255,255,0.01)" : "transparent",minHeight:32}}>
                <div style={{fontSize:7,color:cur ? st.color : done ? "#5a8aa8" : "#364a5c",letterSpacing:"0.06em",marginBottom:4,display:"flex",justifyContent:"space-between",fontFamily:"'JetBrains Mono',monospace",fontWeight:cur?600:400}}>
                  <span>{st.cmd}</span>
                  {ags.length > 0 && <span style={{opacity:0.7}}>{ags.length}</span>}
                </div>
                {ags.map(a => <AgentPill key={a.id} agent={a} state={agState(a)} firing={firing.has(a.id)}/>)}
                {ags.length === 0 && <div style={{fontSize:6.5,color:"#253444",fontStyle:"italic",fontFamily:"'JetBrains Mono',monospace"}}>{st.id === "ship" ? "CI/CD" : "—"}</div>}
              </div>
            );
          })}
        </div>
      </div>

      {/* ── Hooks ── */}
      <div style={{padding:"5px 14px 6px",borderBottom:"1px solid rgba(255,255,255,0.06)",background:"rgba(0,0,0,0.10)"}}>
        <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:5}}>
          <span style={{fontSize:7.5,color:"#5a8898",letterSpacing:"0.1em",fontFamily:"'JetBrains Mono',monospace",fontWeight:600}}>HOOKS · {HOOK_DEFS.length}</span>
          <div style={{flex:1,height:"1px",background:"rgba(255,255,255,0.06)"}}/>
          <span style={{fontSize:6.5,color:"#3a5868",fontStyle:"italic",fontFamily:"'JetBrains Mono',monospace"}}>survol = détails</span>
        </div>
        <div style={{display:"flex",flexWrap:"wrap",gap:4}}>
          {HOOK_DEFS.map(h => {
            const active = firingHooks.has(h.id);
            return (
              <div key={h.id}
                onMouseEnter={e => setHookTooltip({ hook:h, x:(e as React.MouseEvent).clientX+14, y:(e as React.MouseEvent).clientY })}
                onMouseLeave={() => setHookTooltip(null)}
                style={{display:"flex",alignItems:"center",gap:4,padding:"2px 8px 2px 5px",borderRadius:3,cursor:"help",
                  background: active ? `${h.color}1a` : "rgba(255,255,255,0.025)",
                  border: active ? `1px solid ${h.color}70` : "1px solid rgba(255,255,255,0.07)",
                  transition:"all 0.25s",
                  boxShadow: active ? `0 0 8px ${h.color}30` : "none"
                }}
              >
                <div style={{width:5,height:5,borderRadius:"50%",flexShrink:0,
                  background: active ? h.color : "rgba(255,255,255,0.15)",
                  boxShadow: active ? `0 0 6px ${h.color}` : "none",
                  transition:"all 0.25s"
                }}/>
                <span style={{fontSize:7,color: active ? h.color : "#5a7888",fontFamily:"'JetBrains Mono',monospace",whiteSpace:"nowrap",fontWeight:active?600:400,transition:"color 0.25s"}}>{h.name}</span>
              </div>
            );
          })}
        </div>
        {hookTooltip && <HookTooltip hook={hookTooltip.hook} x={hookTooltip.x} y={hookTooltip.y}/>}
      </div>

      {/* ── Garage ── */}
      <div style={{padding:"5px 14px 7px",background:"rgba(0,0,0,0.08)"}}>
        <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:5}}>
          <span style={{fontSize:7.5,color:"#456070",letterSpacing:"0.1em",fontFamily:"'JetBrains Mono',monospace",fontWeight:600}}>GARAGE · {garage.length} agents</span>
          <div style={{flex:1,height:"1px",background:"rgba(255,255,255,0.05)"}}/>
          <span style={{fontSize:6.5,color:"#3a5060",fontStyle:"italic",fontFamily:"'JetBrains Mono',monospace"}}>survol = détails</span>
        </div>
        <div style={{display:"flex",flexWrap:"wrap",gap:4}}>
          {garage.map(a => (
            <div key={a.id}
              onMouseEnter={e => setTooltip({ agent:a, x:(e as React.MouseEvent).clientX+14, y:(e as React.MouseEvent).clientY })}
              onMouseLeave={() => setTooltip(null)}
              style={{display:"flex",alignItems:"center",gap:4,padding:"2px 8px",borderRadius:3,cursor:"help",
                background:"rgba(255,255,255,0.02)",border:"1px dashed rgba(255,255,255,0.07)",
                transition:"all 0.15s",opacity:0.5}}
              onMouseOver={e => { (e.currentTarget as HTMLDivElement).style.opacity="1"; (e.currentTarget as HTMLDivElement).style.background=`${a.color}0d`; (e.currentTarget as HTMLDivElement).style.borderColor=`${a.color}40`; }}
              onMouseOut={e => { (e.currentTarget as HTMLDivElement).style.opacity="0.5"; (e.currentTarget as HTMLDivElement).style.background="rgba(255,255,255,0.02)"; (e.currentTarget as HTMLDivElement).style.borderColor="rgba(255,255,255,0.07)"; }}
            >
              <div style={{width:3,height:3,borderRadius:"50%",background:a.color,opacity:0.6,flexShrink:0}}/>
              <span style={{fontSize:7,color:"#4a6478",fontFamily:"'JetBrains Mono',monospace",whiteSpace:"nowrap"}}>{a.name}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function ArchipelLive() {
  const [pi,     setPi]    = useState(0);
  const [isDemo, setIsDemo] = useState(false);

  const [projects, setProjects] = useState<Project[]>(DEMO_PROJECTS);
  const [evts,     setEvts]    = useState<LiveEvent[]>([]);
  const [notifs,   setNotifs]  = useState<Notif[]>([]);
  const [pulse,    setPulse]   = useState(0);
  const [live,     setLive]    = useState(false);
  const [fading,   setFading]  = useState(false);
  const [firing,      setFiring]      = useState<Set<string>>(new Set());
  const [firingHooks, setFiringHooks] = useState<Set<string>>(new Set());
  const [reworks,  setReworks] = useState<Rework[]>([]);
  const [tooltip,  setTooltip] = useState<TooltipState | null>(null);
  const [allH,     setAllH]    = useState(DEMO_PROJECTS.map(p => p.hooks));
  const [allB,     setAllB]    = useState(DEMO_PROJECTS.map(p => Math.floor(p.hooks * 0.05)));
  const evtCountRef = useRef<number[]>(DEMO_PROJECTS.map(() => 0));
  const piRef = useRef(pi);

  // Lecture ?demo= et fetch projets dans le même effect — pas de race condition
  useEffect(() => {
    const demo = new URLSearchParams(window.location.search).get("demo") === "true";
    setIsDemo(demo);
    if (demo) return;

    fetch(`${MONITOR_URL}/projects`)
      .then(r => r.json())
      .then((data: { projects: Array<{ name: string; path: string; type?: string; cloud?: string; description?: string; stage?: string; agents?: string[]; feedExists: boolean; feedSize: number }> }) => {
        if (data.projects && data.projects.length > 0) {
          const COLORS = ["#f6e05e","#fc8181","#63b3ed","#4fd1c5","#b794f4","#f6ad55","#68d391"];
          const mapped: Project[] = data.projects.map((p, i) => {
            const demo = DEMO_PROJECTS.find(d => d.name === p.name);
            if (demo) return demo;
            const stageId = (p.stage as StageId | undefined) ?? "feature";
            const usedSet = new Set<string>(p.agents ?? []);
            return {
              name: p.name,
              stage: stageId,
              color: COLORS[i % COLORS.length]!,
              type: (p.type as "perso" | "clubmed") ?? "perso",
              cloud: p.cloud ?? "GCP",
              sessions: 0,
              hooks: Math.round((p.feedSize ?? 0) / 80),
              desc: p.description ?? p.name,
              used: usedSet,
            };
          });
          setProjects(mapped);
          setAllH(mapped.map(p => p.hooks));
          setAllB(mapped.map(p => Math.floor(p.hooks * 0.05)));
        }
      })
      .catch(() => {});
  }, []); // exécuté une seule fois au mount

  const proj   = (projects[pi] ?? DEMO_PROJECTS[0])!;
  const curSi  = IDX[proj.stage] ?? 3;
  const projRW = reworks.filter(r => r.proj === proj.name);
  const anyRW  = projRW.length > 0;
  const col    = anyRW ? RWC : (STAGES[curSi]?.color ?? "#fff");
  const pct    = Math.round(curSi / (STAGES.length - 1) * 100);

  useEffect(() => { piRef.current = pi; }, [pi]);

  useEffect(() => {
    if (isDemo) return;
    let es: EventSource | undefined;
    try {
      es = new EventSource(`${MONITOR_URL}/events`);
      es.onopen = () => setLive(true);
      es.onmessage = e => {
        try {
          const d = JSON.parse(e.data as string) as { type?: string; project?: string; ts?: string; msg?: string; dur?: number; agent?: string; hook?: string; rework?: { from: StageId; to: StageId } };
          if (d.type === "connected") return;
          if (d.project && d.project !== projects[piRef.current]?.name) return;
          // Construire un message lisible si vide
          const msg = d.msg || (d.agent ? `${d.agent} — ${d.type ?? "ok"}` : d.hook ? `${d.hook} triggered` : "event");
          push({ id: ++uid, ts: d.ts ?? ts(), type: (d.type ?? "ok") as EventType, msg, dur: d.dur ?? null, ag: d.agent ?? null, hook: d.hook, rw: d.rework ?? null }, piRef.current);
        } catch { /* ignore parse errors */ }
      };
      es.onerror = () => setLive(false);
    } catch { /* ignore */ }
    return () => es?.close();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDemo, projects]);

  useEffect(() => {
    if (!isDemo && live) return;
    const id = setInterval(() => {
      const ti = Math.floor(Math.random() * projects.length);
      const ev = rnd(POOL);
      if (ti === piRef.current) {
        push({ id: ++uid, ts: ts(), type: ev.type, msg: ev.msg, dur: ev.type === "ok" ? Math.floor(Math.random() * 7000) + 200 : null, ag: ev.ag, hook: ev.hook, rw: ev.rw }, ti);
      } else {
        setAllH(p => { const n = [...p]; n[ti] = (n[ti] ?? 0) + 1; return n; });
        if (ev.type === "blocked") setAllB(p => { const n = [...p]; n[ti] = (n[ti] ?? 0) + 1; return n; });
        // Avancement de stage pour les projets hors focus
        if (isDemo) advanceStage(ti, ev.rw ?? null);
      }
    }, 1700);
    return () => clearInterval(id);
  }, [isDemo, live, projects]);

  // Avance ou recule le stage d'un projet (démo uniquement)
  function advanceStage(projIdx: number, rw: { from: StageId; to: StageId } | null) {
    if (!isDemo) return;
    const counts = evtCountRef.current;
    counts[projIdx] = (counts[projIdx] ?? 0) + 1;
    // Rework : reculer au stage cible
    if (rw) {
      setProjects(p => {
        const n = [...p];
        const proj = n[projIdx];
        if (proj) n[projIdx] = { ...proj, stage: rw.to };
        return n;
      });
      counts[projIdx] = 0;
      return;
    }
    // Avancer tous les 10 events OK/agent/write/success
    if ((counts[projIdx] ?? 0) >= 10) {
      counts[projIdx] = 0;
      setProjects(p => {
        const n = [...p];
        const proj = n[projIdx];
        if (!proj) return n;
        const si = IDX[proj.stage] ?? 0;
        const nextSi = (si + 1) % STAGES.length; // cycle discover→spec→…→ship→discover
        n[projIdx] = { ...proj, stage: (STAGES[nextSi]?.id ?? "discover") };
        return n;
      });
    }
  }

  function push(e: LiveEvent, projIdx: number) {
    const pid = ++uid;
    setEvts(p => [e, ...p].slice(0, 50));
    setAllH(p => { const n = [...p]; n[projIdx] = (n[projIdx] ?? 0) + 1; return n; });
    if (e.type === "blocked") setAllB(p => { const n = [...p]; n[projIdx] = (n[projIdx] ?? 0) + 1; return n; });
    setPulse(pid);
    if (e.rw) {
      const rwId = ++uid;
      setReworks(p => [...p, { id: rwId, from: e.rw!.from, to: e.rw!.to, proj: projects[projIdx]?.name ?? "", ts: Date.now() }]);
      setTimeout(() => setReworks(p => p.filter(r => r.id !== rwId)), 15000);
    }
    if (e.ag) {
      setFiring(p => { const n = new Set(p); n.add(e.ag!); return n; });
      setTimeout(() => setFiring(p => { const n = new Set(p); n.delete(e.ag!); return n; }), 3000);
    }
    if (e.hook) {
      setFiringHooks(p => { const n = new Set(p); n.add(e.hook!); return n; });
      setTimeout(() => setFiringHooks(p => { const n = new Set(p); n.delete(e.hook!); return n; }), 2500);
    }
    const c = EC[e.type] ?? "#888";
    const xo = (Math.random() - .5) * 70, yo = -(NR + 16 + Math.random() * 24);
    setNotifs(p => [{ id: pid, x: sx(curSi) + xo, y: NY + yo, msg: e.msg.slice(0, 40) + (e.msg.length > 40 ? "…" : ""), c, rw: !!e.rw, ts: Date.now() }, ...p].slice(0, 9));
    setTimeout(() => setPulse(0), 900);
    // Avancer le stage du projet affiché aussi
    if (isDemo) advanceStage(projIdx, e.rw ?? null);
  }

  useEffect(() => {
    const id = setInterval(() => { const t = Date.now(); setNotifs(p => p.filter(n => t - n.ts < 5500)); }, 500);
    return () => clearInterval(id);
  }, []);

  function switchProj(i: number) {
    if (i === pi) return;
    piRef.current = i;
    setFading(true);
    setTimeout(() => {
      setPi(i); setEvts([]); setNotifs([]); setFiring(new Set());
      setReworks(p => p.filter(r => r.proj === projects[i]?.name));
      setFading(false);
    }, 160);
  }

  return (
    <div style={{background:"radial-gradient(ellipse 140% 130% at 50% 16%,#071222 0%,#030507 65%)",height:"100vh",color:"#c8d6e5",fontFamily:"'JetBrains Mono',monospace",display:"flex",flexDirection:"column",overflow:"hidden"}}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&family=Rajdhani:wght@500;600;700&display=swap');
        *{box-sizing:border-box;margin:0;padding:0}
        ::-webkit-scrollbar{width:3px;height:3px}
        ::-webkit-scrollbar-thumb{background:#142030}
        @keyframes blink{0%,100%{opacity:1}50%{opacity:0}}
        .bl{animation:blink 1s step-end infinite}
        @keyframes notif-in{from{opacity:0;transform:translateY(-8px)}to{opacity:1;transform:none}}
        .ni{animation:notif-in 0.18s ease}
        @keyframes ring-out{0%{transform:scale(1);opacity:0.85}100%{transform:scale(2.2);opacity:0}}
        .pr{animation:ring-out 0.85s ease-out forwards;transform-origin:center;transform-box:fill-box}
        @keyframes halo-br{0%,100%{opacity:0.28}50%{opacity:0.82}}
        .hl{animation:halo-br 2.6s ease-in-out infinite}
        @keyframes rw-dash{from{stroke-dashoffset:0}to{stroke-dashoffset:-40}}
        .rw-path{animation:rw-dash 1.2s linear infinite}
        @keyframes rw-lbl{0%,100%{opacity:0.6}50%{opacity:1}}
        .rw-lbl{animation:rw-lbl 1.4s ease-in-out infinite}
        @keyframes ei{from{opacity:0;transform:translateX(-5px)}to{opacity:1;transform:none}}
        .ei{animation:ei 0.13s ease}
        select{appearance:none;-webkit-appearance:none}
        select option{background:#060e1a;color:#c8d6e5}
      `}</style>

      {/* Header */}
      <div style={{display:"flex",alignItems:"center",padding:"7px 18px",borderBottom:"1px solid rgba(255,255,255,0.06)",background:"rgba(3,5,8,0.94)",backdropFilter:"blur(16px)",flexShrink:0,gap:16}}>
        <div style={{display:"flex",alignItems:"center",gap:8,flexShrink:0}}>
          <span style={{color:"#4fd1c5",fontSize:14}}>⬡</span>
          <span style={{fontFamily:"Rajdhani",fontWeight:700,fontSize:16,letterSpacing:"0.22em",color:"#e8f4ff"}}>ARCHIPEL</span>
          <span style={{fontSize:7,color:"#3a6080",background:"#060d18",padding:"2px 6px",borderRadius:2,border:"1px solid #0d2030"}}>LIVE</span>
        </div>
        <div style={{display:"flex",alignItems:"center",gap:8,flex:1,maxWidth:400}}>
          <span style={{fontSize:7,color:"#4a7090",letterSpacing:"0.1em",flexShrink:0}}>PROJECT</span>
          <div style={{position:"relative",flex:1}}>
            <select value={pi} onChange={e => switchProj(Number(e.target.value))} style={{width:"100%",background:"rgba(255,255,255,0.05)",border:`1px solid ${proj.color}50`,borderRadius:3,color:proj.color,fontFamily:"'JetBrains Mono',monospace",fontSize:9,padding:"5px 28px 5px 10px",cursor:"pointer",letterSpacing:"0.05em",outline:"none"}}>
              {projects.map((p, i) => <option key={p.name} value={i}>{p.name}  /{p.stage}  {p.type === "clubmed" ? "CM" : "PRV"}  {p.cloud}</option>)}
            </select>
            <span style={{position:"absolute",right:8,top:"50%",transform:"translateY(-50%)",pointerEvents:"none",fontSize:9,color:proj.color}}>▾</span>
          </div>
          <div style={{display:"flex",gap:5}}>
            {projects.map((p, i) => (
              <div key={p.name} onClick={() => switchProj(i)} title={p.name} style={{width:9,height:9,borderRadius:"50%",cursor:"pointer",background:p.color,opacity:i === pi ? 1 : 0.3,boxShadow:i === pi ? `0 0 7px ${p.color}` : "none",transition:"all 0.2s"}}/>
            ))}
          </div>
        </div>
        <div style={{display:"flex",alignItems:"center",gap:14,marginLeft:"auto"}}>
          {([{ l:"HOOKS", v:allH[pi] ?? 0, c:"#f6ad55" }, { l:"BLOCKED", v:allB[pi] ?? 0, c:"#fc8181" }, { l:"AGENTS", v:proj.used.size, c:"#7aaad0" }, { l:"GARAGE", v:AGENTS.length - proj.used.size, c:"#4a6a80" }]).map(s => (
            <div key={s.l} style={{textAlign:"center"}}>
              <div style={{fontSize:15,fontFamily:"Rajdhani",fontWeight:700,color:s.c,lineHeight:1}}>{s.v}</div>
              <div style={{fontSize:6.5,color:"#3a5a70",letterSpacing:"0.1em",marginTop:1}}>{s.l}</div>
            </div>
          ))}
          <div style={{display:"flex",alignItems:"center",gap:5,borderLeft:"1px solid rgba(255,255,255,0.07)",paddingLeft:12}}>
            <div className="bl" style={{width:5,height:5,borderRadius:"50%",background:live ? "#68d391" : "#f6ad55"}}/>
            <span style={{fontSize:7,color:live ? "#3a9060" : "#8a7030"}}>{live ? "LIVE · :3999" : "SIMULATION"}</span>
          </div>
        </div>
      </div>

      {/* Body */}
      <div style={{flex:1,display:"flex",flexDirection:"column",overflow:"hidden"}}>
        <div style={{flexShrink:0,opacity:fading ? 0 : 1,transition:"opacity 0.16s"}}>
          <svg viewBox={`0 0 ${VW} ${VH}`} style={{width:"100%",display:"block",maxHeight:300}} preserveAspectRatio="xMidYMid meet">
            {STARS.map((s, i) => <circle key={i} cx={s.cx} cy={s.cy} r={s.r} fill="white" opacity={s.op}/>)}
            <defs>
              <radialGradient id="ng" cx={`${(sx(curSi) / VW * 100).toFixed(0)}%`} cy="55%" r="36%">
                <stop offset="0%" stopColor={col} stopOpacity="0.1"/>
                <stop offset="100%" stopColor={col} stopOpacity="0"/>
              </radialGradient>
              <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
                <feGaussianBlur stdDeviation="3" result="blur"/>
                <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
              </filter>
            </defs>
            <rect x="0" y="0" width={VW} height={VH} fill="url(#ng)"/>

            {/* ══ BUILD ORCHESTRATOR — nœud central au-dessus du pipeline ══ */}
            {(() => {
              const OX = VW / 2;        // centré horizontalement
              const OY = 42;            // au-dessus du pipeline
              const OR = 18;            // rayon
              const isActive = firing.has("build-orchestrator");
              const oc = "#63b3ed";     // couleur orchestrateur — bleu ciel
              return (
                <g key="orchestrator">
                  {/* Lignes vers chaque nœud du pipeline */}
                  {STAGES.map((st, i) => {
                    const tx = sx(i), ty = NY - NR - 2;
                    const done = i < curSi;
                    return (
                      <line key={st.id}
                        x1={OX} y1={OY + OR}
                        x2={tx} y2={ty}
                        stroke={done ? `${oc}40` : `${oc}15`}
                        strokeWidth={done ? 1 : 0.6}
                        strokeDasharray={isActive ? undefined : "4 4"}
                      />
                    );
                  })}
                  {/* Halo si actif */}
                  {isActive && <circle cx={OX} cy={OY} r={OR + 18} fill={`${oc}12`} className="hl"/>}
                  {/* Cercle principal */}
                  <circle cx={OX} cy={OY} r={OR}
                    fill={isActive ? `${oc}25` : "rgba(255,255,255,0.03)"}
                    stroke={isActive ? oc : `${oc}55`}
                    strokeWidth={isActive ? 2 : 1}
                  />
                  {/* Symbole ⬡ */}
                  <text x={OX} y={OY} textAnchor="middle" dominantBaseline="middle"
                    fontSize={13} fill={isActive ? oc : `${oc}80`}
                    fontFamily="JetBrains Mono,monospace">⬡</text>
                  {/* Label */}
                  <text x={OX} y={OY - OR - 6} textAnchor="middle"
                    fontSize={7} fill={isActive ? oc : `${oc}60`}
                    fontFamily="JetBrains Mono,monospace"
                    fontWeight={isActive ? "700" : "400"}>
                    orchestrator
                  </text>
                </g>
              );
            })()}

            {projRW.map((rw, ri) => {
              const fi = IDX[rw.from], ti = IDX[rw.to];
              if (fi === undefined || ti === undefined || fi <= ti) return null;
              const lift = 70 + ri * 38;
              const pid = `rw${rw.id}`;
              const d = rwPath(fi, ti, lift);
              const midX = (sx(fi) + sx(ti)) / 2;
              const midY = NY - lift - 10;
              return (
                <g key={rw.id}>
                  <path d={d} fill="none" stroke={RWC} strokeWidth={6} opacity={0.08}/>
                  <path id={pid} d={d} fill="none" stroke={RWC} strokeWidth={2} strokeDasharray="10 6" className="rw-path" opacity={0.75}/>
                  <g>
                    <circle r={5.5} fill={RWC} opacity={0.95} filter="url(#glow)">
                      <animateMotion dur="1.9s" repeatCount="indefinite" keyPoints="0;1" keyTimes="0;1" calcMode="linear"><mpath href={`#${pid}`}/></animateMotion>
                    </circle>
                    <circle r={2.5} fill="white" opacity={0.7}>
                      <animateMotion dur="1.9s" repeatCount="indefinite" keyPoints="0;1" keyTimes="0;1" calcMode="linear" begin="-0.3s"><mpath href={`#${pid}`}/></animateMotion>
                    </circle>
                  </g>
                  <text x={midX} y={midY} textAnchor="middle" fontSize={9} fill={RWC} fontFamily="JetBrains Mono,monospace" fontWeight="700" className="rw-lbl">↩ /{rw.from} → /{rw.to}</text>
                </g>
              );
            })}

            {STAGES.slice(0, -1).map((_, i) => {
              const done = i < curSi;
              return (
                <g key={i}>
                  <path id={`p${i}`} d={fwdPath(i)} fill="none" stroke={done ? "rgba(255,255,255,0.12)" : "rgba(255,255,255,0.025)"} strokeWidth={done ? 1.5 : 1} strokeDasharray={i >= curSi ? "8 6" : undefined}/>
                  {done && (
                    <circle r={2.8} fill={STAGES[i]?.color ?? "#fff"} opacity={0.88}>
                      <animateMotion dur={`${2.0 + i * 0.2}s`} repeatCount="indefinite" begin={`${-(i * 0.45)}s`}><mpath href={`#p${i}`}/></animateMotion>
                    </circle>
                  )}
                </g>
              );
            })}

            {STAGES.map((st, i) => {
              const x = sx(i), done = i < curSi, cur = i === curSi;
              const isRwSrc = projRW.some(r => IDX[r.from] === i);
              const isRwDst = projRW.some(r => IDX[r.to] === i);
              const nc = cur && anyRW ? RWC : st.color;
              const nr = cur ? NR + 4 : NR;
              return (
                <g key={st.id}>
                  {cur && <circle cx={x} cy={NY} r={nr + 24} fill={`${nc}18`} className="hl"/>}
                  {cur && pulse > 0 && <circle key={`r${pulse}`} cx={x} cy={NY} r={nr} fill="none" stroke={nc} strokeWidth={1.5} className="pr"/>}
                  {isRwSrc && <circle cx={x} cy={NY} r={nr + 9} fill="none" stroke={RWC} strokeWidth={2} strokeDasharray="4 3" opacity={0.7} className="pr" key={`rws${projRW.length}`}/>}
                  {isRwDst && <circle cx={x} cy={NY} r={nr + 6} fill={`${RWC}12`} stroke={RWC} strokeWidth={1} strokeDasharray="3 3" opacity={0.5}/>}
                  <circle cx={x} cy={NY} r={nr} fill={cur ? `${nc}1c` : done ? `${st.color}0c` : "rgba(255,255,255,0.015)"} stroke={cur ? nc : done ? `${st.color}55` : "rgba(255,255,255,0.08)"} strokeWidth={cur ? 2 : done ? 1 : 0.8}/>
                  <text x={x} y={NY} textAnchor="middle" dominantBaseline="middle" fontSize={cur ? 14 : 12} fill={cur ? nc : done ? `${st.color}80` : "#2a4060"} fontFamily="JetBrains Mono,monospace">{st.sym}</text>
                  <text x={x} y={NY + nr + 14} textAnchor="middle" fontSize={8} fontFamily="JetBrains Mono,monospace" fill={cur ? nc : done ? `${st.color}70` : "#3a5878"}>{st.cmd}</text>
                  {done && <text x={x + nr - 4} y={NY - nr + 7} textAnchor="middle" dominantBaseline="middle" fontSize={7} fill={st.color} opacity={0.55} fontFamily="JetBrains Mono,monospace">✓</text>}
                </g>
              );
            })}

            <g transform={`translate(${sx(curSi)},${NY + NR + 36})`}>
              <text x={0} y={0} textAnchor="middle" fontSize={17} fontFamily="Rajdhani,sans-serif" fontWeight="700" fill={col}>{proj.name}</text>
              {anyRW
                ? <text x={0} y={15} textAnchor="middle" fontSize={8} fill={RWC} fontFamily="JetBrains Mono,monospace">{projRW.map(r => `↩ /${r.from} → /${r.to}`).join("  ")}</text>
                : <text x={0} y={15} textAnchor="middle" fontSize={7.5} fill="#4a7090" fontFamily="JetBrains Mono,monospace">{proj.sessions}s · {proj.hooks}h · {proj.type} · {proj.cloud}</text>
              }
            </g>

            <g transform={`translate(${sx(0)},${VH - 10})`}>
              <rect x={0} y={0} width={sx(6) - sx(0)} height={1.5} rx={1} fill="rgba(255,255,255,0.04)"/>
              <rect x={0} y={0} width={(sx(6) - sx(0)) * (curSi / (STAGES.length - 1))} height={1.5} rx={1} fill={col} opacity={0.55}/>
            </g>

            {notifs.map(n => {
              const w = Math.min(n.msg.length * 5.1 + 18, 250);
              return (
                <g key={n.id} className="ni">
                  <rect x={n.x - w / 2} y={n.y - 12} width={w} height={16} rx={4} fill="rgba(3,5,10,0.96)" stroke={n.rw ? `${RWC}70` : `${n.c}50`} strokeWidth={n.rw ? 1.5 : 1}/>
                  <text x={n.x} y={n.y - 1} textAnchor="middle" fontSize={7.5} fill={n.rw ? RWC : n.c} fontFamily="JetBrains Mono,monospace">{n.msg}</text>
                </g>
              );
            })}
          </svg>
        </div>

        <div style={{flex:1,display:"flex",overflow:"hidden",borderTop:"1px solid rgba(255,255,255,0.06)",opacity:fading ? 0 : 1,transition:"opacity 0.16s"}}>
          <div style={{flex:1,overflowY:"auto",display:"flex",flexDirection:"column"}}>
            <AgentsSection proj={proj} curSi={curSi} firing={firing} firingHooks={firingHooks} setTooltip={setTooltip}/>
          </div>
          <div style={{width:258,flexShrink:0,borderLeft:"1px solid rgba(255,255,255,0.06)",display:"flex",flexDirection:"column",background:"rgba(0,0,0,0.15)"}}>
            <div style={{padding:"7px 12px",borderBottom:"1px solid rgba(255,255,255,0.05)",flexShrink:0}}>
              <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:3}}>
                <span style={{fontSize:10,color:col,fontFamily:"Rajdhani",fontWeight:600}}>{proj.name}</span>
                <div style={{display:"flex",gap:3}}>
                  <span style={{fontSize:7,color:proj.type === "clubmed" ? "#f6ad55" : "#4fd1c5",background:proj.type === "clubmed" ? "rgba(246,173,85,0.12)" : "rgba(79,209,197,0.12)",padding:"1px 5px",borderRadius:2,border:proj.type === "clubmed" ? "1px solid rgba(246,173,85,0.3)" : "1px solid rgba(79,209,197,0.3)"}}>{proj.type === "clubmed" ? "CM" : "PRV"}</span>
                  <span style={{fontSize:7,color:"#63b3ed",background:"rgba(99,179,237,0.12)",padding:"1px 5px",borderRadius:2,border:"1px solid rgba(99,179,237,0.3)"}}>{proj.cloud}</span>
                </div>
              </div>
              <div style={{fontSize:7.5,color:"#4a7090",lineHeight:1.4}}>{proj.desc}</div>
              {anyRW && (
                <div style={{marginTop:5,padding:"4px 8px",background:"rgba(255,153,68,0.08)",border:"1px solid rgba(255,153,68,0.30)",borderRadius:3}}>
                  {projRW.map(r => <div key={r.id} style={{fontSize:8,color:RWC,fontWeight:"bold"}}>↩ /{r.from} → /{r.to}</div>)}
                </div>
              )}
            </div>
            <div style={{fontSize:7,color:"#4a7090",letterSpacing:"0.08em",padding:"3px 12px 2px",borderBottom:"1px solid rgba(255,255,255,0.04)",flexShrink:0}}>EVENTS · {proj.name}</div>
            <div style={{flex:1,overflowY:"auto"}}>
              {evts.length === 0 && <div style={{padding:"10px 12px",fontSize:8,color:"#3a5870",fontStyle:"italic"}}>en attente…</div>}
              {evts.map((e, i) => {
                const c = EC[e.type] ?? "#888";
                return (
                  <div key={e.id} className={i === 0 ? "ei" : ""} style={{padding:"2px 11px",display:"flex",gap:6,alignItems:"baseline",background:e.rw ? "rgba(255,153,68,0.06)" : e.type === "blocked" ? "rgba(252,129,129,0.05)" : "transparent",borderLeft:`2px solid ${i < 2 ? (e.rw ? RWC : c) + "60" : "transparent"}`}}>
                    <span style={{fontSize:7,color:"#3a5a70",flexShrink:0,width:42}}>{e.ts}</span>
                    {e.rw && <span style={{fontSize:9,color:RWC,flexShrink:0}}>↩</span>}
                    <span style={{fontSize:7.5,color:e.rw ? RWC : c,flex:1,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{e.msg}</span>
                    {e.dur && <span style={{fontSize:6.5,color:"#3a5a70",flexShrink:0}}>{e.dur > 1000 ? `${(e.dur / 1000).toFixed(1)}s` : `${e.dur}ms`}</span>}
                  </div>
                );
              })}
            </div>
            <div style={{padding:"6px 11px",borderTop:"1px solid rgba(255,255,255,0.05)",flexShrink:0}}>
              <div style={{height:2,background:"rgba(255,255,255,0.06)",borderRadius:1,marginBottom:3}}>
                <div style={{width:`${pct}%`,height:"100%",borderRadius:1,background:col,opacity:0.65,transition:"width 0.4s,background 0.4s"}}/>
              </div>
              <div style={{fontSize:7,color:"#3a5a70",display:"flex",justifyContent:"space-between"}}>
                <span>/discover</span>
                <span style={{color:col}}>{pct}% · {STAGES[curSi]?.cmd}</span>
                <span>/ship</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <div style={{padding:"4px 18px",borderTop:"1px solid rgba(255,255,255,0.06)",background:"rgba(3,5,8,0.90)",flexShrink:0,display:"flex",justifyContent:"space-between",alignItems:"center"}}>
        <span style={{fontSize:7,color:"#3a5870",letterSpacing:"0.08em"}}>ARCHIPEL · 38 AGENTS · 16 HOOKS · SHELL 82% · PY 11% · TS 5% · AUDIT 8.3/10</span>
        <span style={{fontSize:7,color:isDemo ? "#b794f4" : live ? "#3a9060" : "#7a6030",letterSpacing:"0.08em"}}>{isDemo ? "◈ DEMO — données fictives" : live ? "● LIVE · localhost:3999" : "◌ SIMULATION — node monitor.js"}</span>
      </div>

      {tooltip && <Tooltip agent={tooltip.agent} x={tooltip.x} y={tooltip.y}/>}
    </div>
  );
}

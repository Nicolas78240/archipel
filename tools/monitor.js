#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────
// Archipel Monitor — companion server local
// Usage : node tools/monitor.js  (ou npm run monitor)
// Port  : 3999 (localhost only)
//
// Endpoints :
//   GET /events    → SSE — tail de tous les feeds enregistrés
//   GET /agents    → liste agents dans .claude/agents/
//   GET /projects  → liste des projets enregistrés + statut feed
//   GET /health    → status JSON (inclut nb de projets watchés)
//   GET /push?json=... → injection debug
// ─────────────────────────────────────────────────────────────────

const fs   = require("fs");
const http = require("http");
const path = require("path");

const PORT       = 3999;
const ROOT       = path.resolve(__dirname, "..");
const AGENTS_DIR = path.join(ROOT, ".claude", "agents");

// ── Charger les projets depuis .archipel/projects.json ───────────
function loadProjects() {
  const f = path.join(ROOT, ".archipel", "projects.json");
  try {
    return JSON.parse(fs.readFileSync(f, "utf8")).projects ?? [];
  } catch { return []; }
}

// ── SSE clients ───────────────────────────────────────────────────
const clients = new Set();

function broadcast(line) {
  for (const res of clients) {
    try { res.write(`data: ${line}\n\n`); }
    catch { clients.delete(res); }
  }
}

// ── Watch multi-feeds ─────────────────────────────────────────────
// Garder trace des feeds déjà watchés pour éviter les doublons
const watchedFeeds = new Set();

function watchFeeds() {
  const projects = loadProjects();

  // Toujours watch le feed local Archipel lui-même
  const feeds = [
    { name: "Archipel", feed: path.join(ROOT, "tasks", "live-events.jsonl") },
    ...projects.map(p => ({
      name: p.name,
      feed: path.join(p.path, "tasks", "live-events.jsonl")
    }))
  ];

  feeds.forEach(({ name, feed }) => {
    // Skip si déjà watché
    if (watchedFeeds.has(feed)) return;

    // Repo absent → skip silencieux
    if (!fs.existsSync(path.dirname(feed))) {
      console.log(`  · skip ${name}: répertoire absent (${path.dirname(feed)})`);
      return;
    }

    // Créer le feed s'il n'existe pas
    if (!fs.existsSync(feed)) fs.writeFileSync(feed, "");

    let pos = fs.statSync(feed).size;
    watchedFeeds.add(feed);

    fs.watch(feed, () => {
      try {
        const { size } = fs.statSync(feed);
        if (size <= pos) { pos = size; return; }
        const buf = Buffer.alloc(size - pos);
        const fd  = fs.openSync(feed, "r");
        fs.readSync(fd, buf, 0, buf.length, pos);
        fs.closeSync(fd);
        pos = size;
        buf.toString().split("\n").filter(l => l.trim()).forEach(line => {
          broadcast(line);
          // log console avec prefix projet
          try {
            const ev  = JSON.parse(line);
            const sym = ev.type === "blocked" ? "✗" : ev.type === "warn" ? "⚠" : "✓";
            const ag  = ev.agent ? ` [${ev.agent}]` : "";
            console.log(`  ${sym} [${name}] ${ev.ts ?? "??:??:??"}${ag} — ${String(ev.msg ?? "").slice(0, 72)}`);
          } catch {}
        });
      } catch (e) { console.error(`watch(${name}):`, e.message); }
    });

    console.log(`  · watching ${name}: ${feed}`);
  });
}

// ── Watch projects.json pour rechargement automatique ─────────────
const projectsFile = path.join(ROOT, ".archipel", "projects.json");
if (fs.existsSync(projectsFile)) {
  fs.watch(projectsFile, () => {
    console.log("  → projects.json modifié, rechargement des feeds...");
    watchFeeds();
  });
}

// ── Agent discovery ───────────────────────────────────────────────
function discoverAgents() {
  if (!fs.existsSync(AGENTS_DIR)) return [];
  return fs.readdirSync(AGENTS_DIR)
    .filter(f => /\.(md|yml|yaml)$/.test(f))
    .map(f => {
      const id = path.basename(f, path.extname(f));
      let stage = null;
      try {
        const txt = fs.readFileSync(path.join(AGENTS_DIR, f), "utf8");
        const m   = txt.match(/^stage\s*:\s*["']?([a-z]+)["']?/im);
        if (m) stage = m[1];
      } catch {}
      return { id, stage };
    });
}

// ── HTTP ──────────────────────────────────────────────────────────
http.createServer((req, res) => {
  // localhost only
  const ip = req.socket.remoteAddress ?? "";
  if (!["::1","127.0.0.1","::ffff:127.0.0.1"].includes(ip)) {
    res.writeHead(403); return res.end("forbidden");
  }

  res.setHeader("Access-Control-Allow-Origin",  "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,OPTIONS");
  if (req.method === "OPTIONS") { res.writeHead(204); return res.end(); }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname === "/events") {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "X-Accel-Buffering": "no",
    });
    res.write(`data: {"type":"connected","agents":${discoverAgents().length},"projects":${loadProjects().length + 1}}\n\n`);
    // replay last 3KB du feed Archipel local
    const localFeed = path.join(ROOT, "tasks", "live-events.jsonl");
    try {
      const { size } = fs.statSync(localFeed);
      const start = Math.max(0, size - 3072);
      const buf   = Buffer.alloc(size - start);
      const fd    = fs.openSync(localFeed, "r");
      fs.readSync(fd, buf, 0, buf.length, start);
      fs.closeSync(fd);
      buf.toString().split("\n").filter(l => l.trim())
        .forEach(l => res.write(`data: ${l}\n\n`));
    } catch {}
    clients.add(res);
    console.log(`[+] SSE client (${clients.size} actif(s))`);
    const hb = setInterval(() => { try { res.write(": hb\n\n"); } catch { clearInterval(hb); }}, 20000);
    req.on("close", () => { clients.delete(res); clearInterval(hb); console.log(`[-] SSE client (${clients.size} actif(s))`); });
    return;
  }

  if (url.pathname === "/agents") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify(discoverAgents()));
  }

  if (url.pathname === "/projects") {
    const projects = loadProjects();

    // Lire les agents réellement invoqués dans un projet (depuis le feed live-events.jsonl)
    // Retourne uniquement les agents qui ont émis un event "started" — pas tout le catalogue
    function readAgents(projectPath) {
      const feedPath = path.join(projectPath, "tasks", "live-events.jsonl");
      if (!fs.existsSync(feedPath)) return [];
      try {
        const lines = fs.readFileSync(feedPath, "utf8").split("\n").filter(l => l.trim());
        const agents = new Set();
        for (const line of lines) {
          try {
            const ev = JSON.parse(line);
            if (ev.agent && (ev.type === "agent" || ev.type === "ok")) {
              agents.add(ev.agent);
            }
          } catch {}
        }
        return [...agents];
      } catch { return []; }
    }

    // Lire le stage courant depuis .archipel/project.json
    function readStage(projectPath) {
      try {
        const meta = JSON.parse(fs.readFileSync(path.join(projectPath, ".archipel", "project.json"), "utf8"));
        return meta.stage ?? null;
      } catch { return null; }
    }

    // Projet racine Archipel lui-même
    let rootProject = null;
    try {
      const rootMeta = JSON.parse(fs.readFileSync(path.join(ROOT, ".archipel", "project.json"), "utf8"));
      const rootFeed = path.join(ROOT, "tasks", "live-events.jsonl");
      rootProject = {
        name: rootMeta.name ?? "Archipel",
        path: ROOT,
        type: rootMeta.type ?? "perso",
        cloud: rootMeta.cloud ?? "GCP",
        description: rootMeta.description ?? "",
        stage: rootMeta.stage ?? null,
        agents: readAgents(ROOT),
        feedExists: fs.existsSync(rootFeed),
        feedSize: (() => { try { return fs.statSync(rootFeed).size; } catch { return 0; } })()
      };
    } catch {}

    const result = projects.map(p => ({
      ...p,
      stage: readStage(p.path),
      agents: readAgents(p.path),
      feedExists: fs.existsSync(path.join(p.path, "tasks", "live-events.jsonl")),
      feedSize: (() => {
        try { return fs.statSync(path.join(p.path, "tasks", "live-events.jsonl")).size; }
        catch { return 0; }
      })()
    }));

    const all = rootProject ? [rootProject, ...result] : result;
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ projects: all }));
  }

  if (url.pathname === "/health") {
    const projects = loadProjects();
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({
      ok: true,
      clients: clients.size,
      agents: discoverAgents().length,
      projects: projects.length + 1, // +1 pour Archipel lui-même
      watchedFeeds: watchedFeeds.size,
      uptime: process.uptime()
    }));
  }

  if (url.pathname === "/push") {
    const json = url.searchParams.get("json");
    if (json) {
      const localFeed = path.join(ROOT, "tasks", "live-events.jsonl");
      try { JSON.parse(json); fs.appendFileSync(localFeed, json + "\n"); res.writeHead(200); return res.end("ok\n"); }
      catch (e) { res.writeHead(400); return res.end(`bad json: ${e.message}\n`); }
    }
  }

  res.writeHead(404); res.end();

}).listen(PORT, "127.0.0.1", () => {
  console.log(`\n  ⬡  Archipel Monitor\n  ──────────────────────────────────────`);
  console.log(`  SSE      →  http://localhost:${PORT}/events`);
  console.log(`  Agents   →  http://localhost:${PORT}/agents`);
  console.log(`  Projects →  http://localhost:${PORT}/projects`);
  console.log(`  Health   →  http://localhost:${PORT}/health`);
  console.log(`  Root     →  ${ROOT}\n`);

  const ag = discoverAgents();
  ag.forEach(a => console.log(`  · ${a.id}${a.stage ? ` (/${a.stage})` : ""}`));
  if (!ag.length) console.log("  (aucun agent détecté dans .claude/agents/)");

  const projects = loadProjects();
  console.log(`\n  Projets enregistrés : ${projects.length}`);
  projects.forEach(p => console.log(`  · ${p.name}: ${p.path}`));

  console.log("\n  Démarrage du watch des feeds...");
  watchFeeds();
  console.log("\n  En attente d'événements…\n");
});

// ─────────────────────────────────────────────────────────────────
// INTÉGRATION HOOKS — ajouter dans chaque .claude/hooks/*.sh :
//
// _ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
// _FEED="$_ROOT/tasks/live-events.jsonl"
// _TS=$(date -u +%H:%M:%S)
// _PROJ=$(python3 -c "import sys,json;print(json.load(open('$_ROOT/.archipel/project.json')).get('name','?'))" 2>/dev/null||echo "?")
//
// # OK    → {"ts":"$_TS","hook":"on-bash.sh","type":"ok","project":"$_PROJ","msg":"$CMD","dur":$DUR}
// # GATE  → {"ts":"$_TS","hook":"on-bash.sh","type":"blocked","project":"$_PROJ","msg":"$CMD"}
// # AGENT → {"ts":"$_TS","hook":"on-subagent-start","type":"agent","project":"$_PROJ","agent":"$ID","msg":"$ID → $TARGET"}
// # REWORK→ {"ts":"$_TS","hook":"on-stop","type":"blocked","project":"$_PROJ","msg":"...","rework":{"from":"review","to":"feature"}}
//
// echo "<json>" >> "$_FEED"
// ─────────────────────────────────────────────────────────────────

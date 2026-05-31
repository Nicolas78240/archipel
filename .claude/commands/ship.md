# /ship — CI/CD → Deploy

Déploie le projet selon la target définie dans `.archipel/project.json`.
Mode perso : GitHub Actions → GCP → prod direct.
Mode clubmed : GitLab CI → Azure → staging → validation → prod.

---

## Usage

```
/ship
```

Doit être lancé depuis une branche `feat/*` ou `fix/*` après `/feature`.

---

## Protocole d'exécution

### Étape 0 — Lire la target et les lessons CI

```bash
# Lessons pertinentes au CI/CD
grep -B 1 -A 8 "#ci\|#config" tasks/lessons.md 2>/dev/null \
  || echo "Aucune leçon CI"
```

### Étape 0b — Lire la target (OBLIGATOIRE)

```bash
cat .archipel/project.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['type'], d['deploy_strategy'])"
```

Ne jamais hardcoder la target. Toujours dériver depuis `project.json`.

---

## Mode perso (type == "perso")

### Étape 1 — Vérifications pré-push

```bash
# Scan secrets
gitleaks detect --no-git

# Tests finaux
cd apps/web && npm test -- --passWithNoTests
cd ../../apps/api && python -m pytest --tb=short

# Lint final
cd apps/web && npx eslint src/ --max-warnings 0
cd ../../apps/api && ruff check .

# Audit dépendances vulnérables
cd apps/web && npm audit --audit-level=high
cd ../../apps/api && pip-audit 2>/dev/null || safety check 2>/dev/null || echo "pip-audit/safety non installé — skip"
```

### Étape 2 — Push vers GitHub

```bash
git push origin $(git branch --show-current)
```

### Étape 3 — Ouvrir une PR (si pas encore fait)

```bash
gh pr create --title "feat: <titre>" --body "Closes <JIRA-ID>"
```

### Étape 4 — Boucle pipeline GitHub Actions

```bash
gh run watch
```

```
TANT QUE (pipeline != vert) :
  1. Lire les logs d'échec : gh run view --log-failed
  2. Identifier le job et l'étape qui échoue
  3. Corriger le code ou la configuration
  4. Re-push : git push origin $(git branch --show-current)
  5. Attendre le nouveau run : gh run watch
  6. Revenir au début de la boucle
```

Ne merger QUE quand le pipeline est vert. Ne jamais forcer le merge sur pipeline rouge.

### Étape 5 — Vérifier le deploy GCP

```bash
# Lire les noms de services depuis project.json
SERVICE_WEB=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d['services']['web'])")
SERVICE_API=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d['services']['api'])")

GCP_REGION=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d.get('gcp_region', 'europe-west1'))")

URL_WEB=$(gcloud run services describe "$SERVICE_WEB" --region "$GCP_REGION" --format="value(status.url)" 2>/dev/null)
URL_API=$(gcloud run services describe "$SERVICE_API" --region "$GCP_REGION" --format="value(status.url)" 2>/dev/null)

# Health checks
[ -n "$URL_WEB" ] && curl -f "$URL_WEB/health" || echo "⚠️ Service web non trouvé ou non démarré"
[ -n "$URL_API" ] && curl -f "$URL_API/health" || echo "⚠️ Service api non trouvé ou non démarré"
```

### Étape 6 — Mise à jour du suivi

```bash
JIRA=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d.get('jira_project',''))" 2>/dev/null)
```

**Mode Jira :** passer le ticket en "Done" via MCP Atlassian.
**Mode solo :** cocher la release dans `docs/tasks.md`, ajouter une note dans `tasks/session-log.md`.

---

## Mode clubmed (type == "clubmed")

### Étape 1 — Vérifications pré-push (identiques au mode perso)

```bash
gitleaks detect --no-git
cd apps/web && npm test -- --passWithNoTests
cd ../../apps/api && python -m pytest --tb=short
cd apps/web && npm audit --audit-level=high
cd ../../apps/api && pip-audit 2>/dev/null || safety check 2>/dev/null || true
```

### Étape 2 — Push vers GitLab

```bash
git push origin $(git branch --show-current)
```

### Étape 3 — Ouvrir une MR GitLab

```bash
glab mr create --title "feat: <titre>" --description "Closes <JIRA-ID>"
```

### Étape 4 — Boucle pipeline GitLab CI

```bash
glab ci status --watch
```

```
TANT QUE (pipeline != vert) :
  1. Lire les logs d'échec : glab ci view
  2. Identifier le job qui échoue
  3. Corriger et re-push
  4. Attendre le nouveau run
  5. Revenir au début de la boucle
```

Pipeline vert → deploy sur **staging** automatique.

### Étape 5 — Boucle validation manuelle staging

```
TANT QUE (staging non validé) :
  1. Afficher l'URL de staging
  2. Demander via AskUserQuestion :
     - `staging OK` → continuer vers prod
     - `problème détecté` → décrire le problème (via "Other")
                            retourner en /feature pour correction
                            puis REVENIR en /ship depuis le début
  3. Si `staging OK` → sortir de la boucle
```

### Étape 6 — Deploy prod Azure

```bash
glab mr merge --when-pipeline-succeeds
```

Déclenche le job `deploy-prod` dans GitLab CI (environnement `production`).

### Étape 7 — Vérifier le deploy Azure

```bash
SERVICE_WEB=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d['services']['web'])")
SERVICE_API=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d['services']['api'])")
RG=$(python3 -c "import json; d=json.load(open('.archipel/project.json')); print(d['azure_resource_group'])")

FQDN_WEB=$(az containerapp show --name "$SERVICE_WEB" --resource-group "$RG" --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null)
FQDN_API=$(az containerapp show --name "$SERVICE_API" --resource-group "$RG" --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null)

[ -n "$FQDN_WEB" ] && curl -f "https://$FQDN_WEB/health" || echo "⚠️ Container app web non trouvé"
[ -n "$FQDN_API" ] && curl -f "https://$FQDN_API/health" || echo "⚠️ Container app api non trouvé"
```

### Étape 8 — Mettre à jour Jira → Done

Via MCP Atlassian : passer le ticket en "Done".

---

## Écriture dans lessons.md (si pipeline a échoué)

Si la boucle pipeline a nécessité plus d'une itération (job rouge, correction, re-push),
écrire une entrée dans `tasks/lessons.md` :
- Quel job a échoué et pourquoi
- Ce qui a été corrigé dans la config ou le code
- La règle pour ne pas reproduire
- Tags : `#ci` et/ou `#config`

## Session log — écrire à chaque /ship

```bash
cat >> tasks/session-log.md << EOF

### $(date -I) — /ship
**Action** : Deploy $(git branch --show-current) en production
**Livrable** : $(git log -1 --format="%s")
**Résultat** : OK
**Prochaine étape** : Surveiller les logs 15 min post-deploy
EOF
```

## Monitoring post-deploy (15 minutes)

Après le health check initial, surveiller brièvement les logs d'erreur :

**Perso (GCP) :**
```bash
# Logs Cloud Run web — chercher les 4xx/5xx
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~\"ERROR|Exception\"" \
  --freshness=15m --limit=20 2>/dev/null || echo "gcloud non configuré localement"
```

**Clubmed (Azure) :**
```bash
# Logs Container App
az containerapp logs show --name "$SERVICE_WEB" --resource-group "$RG" \
  --follow --tail 50 2>/dev/null || echo "az non configuré localement"
```

Si des erreurs apparaissent dans les 15 minutes → investiguer avant de clore le ticket.

## Critère de sortie

- Pipeline CI vert
- Health checks prod répondent 200 (web + api)
- Ticket Jira en "Done"
- Lessons écrites si pipeline a échoué
- Session log écrit dans `tasks/session-log.md`

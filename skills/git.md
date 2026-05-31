# Skill — Git

## Conventional Commits

Format : `<type>(<scope>): <description> [<JIRA-ID>]`

### Types
| Type       | Quand                                              |
|------------|----------------------------------------------------|
| `feat`     | Nouvelle fonctionnalité                            |
| `fix`      | Correction de bug                                  |
| `chore`    | Maintenance, dépendances, config                   |
| `refactor` | Refactoring sans changement de comportement        |
| `test`     | Ajout ou modification de tests                     |
| `docs`     | Documentation uniquement                           |
| `ci`       | Modifications CI/CD                                |
| `perf`     | Amélioration de performance                        |

### Scopes (dérivés de la structure Archipel)
- `web` — apps/web/
- `api` — apps/api/
- `workers` — workers/
- `db` — shared/db/
- `ci` — ci/
- `config` — .archipel/, .claude/

### Exemples
```
feat(web): add user authentication page [ARCH-12]
fix(api): correct pagination offset calculation [ARCH-34]
feat(db): add user_sessions table [ARCH-12]
chore(ci): update Node.js version to 22 in GitHub Actions
refactor(api): extract business logic from user router
test(web): add coverage for UserProfile component
```

## Branches

### Nommage
```
feat/<jira-id>     # feat/ARCH-42
fix/<jira-id>      # fix/ARCH-99
chore/<description> # chore/update-deps
```

### Workflow
```bash
# 1. Créer la branche depuis main à jour
git checkout main && git pull
git checkout -b feat/ARCH-42

# 2. Committer régulièrement (petits commits atomiques)
git add src/components/UserForm.tsx
git commit -m "feat(web): add UserForm component skeleton [ARCH-42]"

# 3. Push et ouvrir PR/MR
git push origin feat/ARCH-42
```

## PR Template

À créer dans `.github/pull_request_template.md` :

```markdown
## Contexte
<!-- Quel problème résout cette PR ? Lien Jira -->

## Changements
<!-- Liste des modifications principales -->

## Checklist
- [ ] Tests ajoutés/mis à jour (coverage > 80%)
- [ ] Lint propre (eslint + ruff)
- [ ] Migrations versionnées si schéma modifié
- [ ] Pas de secrets dans le code
- [ ] Comportement testé manuellement
```

## Règles de staging

```bash
# Toujours stager fichier par fichier, jamais en masse
git add src/components/UserForm.tsx   # ✅
git add .                              # ❌ — risque d'inclure .env, secrets

# Vérifier avant de committer
git diff --staged
```

## Protection secrets (pré-push)

Le hook PreToolUse lance gitleaks automatiquement avant tout `git push`.
Si gitleaks détecte un secret, le push est bloqué.

```bash
# Test manuel
gitleaks detect --no-git
```

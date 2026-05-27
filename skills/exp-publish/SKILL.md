---
name: exp-publish
description: Publish the vault to a new private GitHub repo and wire auto-push so every /exp-* commit syncs to GitHub. Run ONCE per project after /exp-init. Uses the `gh` CLI (must be installed + authenticated). Default name = <project-folder>-vault, private. After this, clone the vault on your laptop and open in Obsidian.
argument-hint: "[--name=<repo>] [--public] [--org=<github-org>]"
allowed-tools: Bash(gh *) Bash(git *) Bash(test *) Bash(cat *) Bash(chmod *) Bash(basename *) Bash(source *) Read Write
---

# exp-publish — wire vault to GitHub auto-sync

You are running `/exp-publish`. Goal: create a GitHub repo for the vault, push current state, install a post-commit hook so every future vault commit auto-pushes.

This skill is run ONCE per project, after `/exp-init` and (typically) at least one `/exp-new`.

## 1. Parse args

From `$ARGUMENTS`:
- `--name=<repo>` — repo name. Default: `<project-folder>-vault`.
- `--public` — make repo public. Default: private.
- `--org=<org>` — create in a GitHub org. Default: current user.

## 2. Inspect

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"

# Vault must exist
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT")
PROJECT_NAME=$(basename "$REPO_ROOT")
cd "$REPO_ROOT"

# gh CLI required
if ! command -v gh >/dev/null 2>&1; then
  exp_die "gh CLI not found. Install: brew install gh  (or visit https://cli.github.com)"
fi

# gh must be authenticated
if ! gh auth status >/dev/null 2>&1; then
  exp_die "gh not authenticated. Run: gh auth login"
fi

GH_USER=$(gh api user --jq .login 2>/dev/null || echo "")
[[ -z "$GH_USER" ]] && exp_die "could not read gh user — check gh auth status"

# Vault repo state
cd "$VAULT"
EXISTING_REMOTE=$(git remote get-url origin 2>/dev/null || true)
VAULT_HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "")
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")

if [[ -n "$EXISTING_REMOTE" ]]; then
  exp_die "vault already has origin remote: $EXISTING_REMOTE
To re-publish: unset and retry → cd '$VAULT' && git remote remove origin"
fi
[[ "$COMMIT_COUNT" == "0" ]] && exp_die "vault has no commits yet. Run /exp-init first."

# Derive target repo name
DEFAULT_NAME="${PROJECT_NAME}-vault"
# (Claude: substitute USER_NAME / ORG / VISIBILITY based on flags here)
echo "GH_USER=$GH_USER"
echo "PROJECT_NAME=$PROJECT_NAME"
echo "DEFAULT_REPO=$DEFAULT_NAME"
echo "VAULT_HEAD=$VAULT_HEAD"
echo "COMMIT_COUNT=$COMMIT_COUNT"
```

If the inspect block errors, STOP and report verbatim. Do not proceed.

## 3. Preview

Substitute the values gathered in step 2 + parsed flags:

```
About to publish vault to GitHub:
  vault path:      <VAULT>
  vault HEAD:      <VAULT_HEAD>  (<COMMIT_COUNT> commits)
  target repo:     <OWNER>/<REPO_NAME>      (e.g. triquang26/ctrl-world-vault)
  visibility:      private    # or "public" if --public
  
Steps:
  1. gh repo create <OWNER>/<REPO_NAME> --<private|public> --description "Experiment vault for <PROJECT>"
  2. cd <VAULT> && git remote add origin git@github.com:<OWNER>/<REPO_NAME>.git
  3. git push -u origin main
  4. Install post-commit hook at <VAULT>/.git/hooks/post-commit
     (auto-pushes every future vault commit)

Confirm? (y/n)
```

Ask: "Confirm? (y/n)". Abort on anything but `y`.

## 4. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault); REPO_ROOT=$(exp_repo_root "$VAULT")
GH_USER="<gh-user>"
ORG="<org-or-empty>"
REPO_NAME="<repo-name>"
VISIBILITY="<--private|--public>"
PROJECT_NAME="<project>"

# Resolve owner: org if --org=, else current user
if [[ -n "$ORG" ]]; then
  OWNER="$ORG"
else
  OWNER="$GH_USER"
fi
FULL_REPO="${OWNER}/${REPO_NAME}"

# Step 4.1 — create repo on GitHub
if ! gh repo create "$FULL_REPO" $VISIBILITY \
       --description "Experiment vault for ${PROJECT_NAME}" \
       --confirm 2>&1; then
  exp_die "gh repo create failed (does the repo already exist?)"
fi

# Step 4.2 — add remote + push
cd "$VAULT"
git remote add origin "git@github.com:${FULL_REPO}.git"
if ! git push -u origin main 2>&1; then
  # rollback: remove remote so user can retry
  git remote remove origin
  exp_die "git push failed. Remote removed; you can retry. Check ssh access to GitHub: ssh -T git@github.com"
fi

# Step 4.3 — install post-commit hook
HOOK="$VAULT/.git/hooks/post-commit"
cat >"$HOOK" <<'EOF'
#!/usr/bin/env bash
# Auto-push vault to origin after every commit. Silent on failure (offline OK).
git push origin main --quiet 2>/dev/null || true
EOF
chmod +x "$HOOK"

# Step 4.4 — verify hook is executable
[[ -x "$HOOK" ]] || exp_die "hook not executable: $HOOK"

echo "FULL_REPO=$FULL_REPO"
echo "REMOTE_URL=git@github.com:${FULL_REPO}.git"
```

If any step fails, report which step + error. Step 4.2 already rolls back the remote on failure; user can re-run safely.

## 5. Report

Tell the user (substitute values):

```
✓ Vault published

GitHub:       https://github.com/<OWNER>/<REPO_NAME>
Remote:       git@github.com:<OWNER>/<REPO_NAME>.git
Vault path:   <VAULT>
Hook:         <VAULT>/.git/hooks/post-commit installed

Every future /exp-new / /exp-branch / /exp-record / /exp-link
will auto-push the vault commit to this repo.

────────────────────────────────────────────────────────────────
On your LAPTOP, clone the vault for Obsidian:

    git clone git@github.com:<OWNER>/<REPO_NAME>.git ~/vaults/<PROJECT_NAME>
    open -a Obsidian ~/vaults/<PROJECT_NAME>

To auto-pull every 30 s (macOS LaunchAgent), see docs/SYNC.md
in the research-infra repo.
────────────────────────────────────────────────────────────────
```

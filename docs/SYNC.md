# Sync vault from server → local Obsidian

The vault (`<repo>/experiments/`) is a **nested git repo**. You have 3 ways to view it on your laptop while it lives on a remote SSH box.

| Option | Pros | Cons | Pick when |
|---|---|---|---|
| **A — Vault as its own GitHub remote** | clean git history; auto-push on commit; offline-capable on local | one extra GitHub repo per project | default — recommended |
| **B — rsync** | no GitHub; one-line cmd | manual / scheduled refresh; no history | quick-and-dirty single project |
| **C — SSHFS mount** | always live, no copy | latency; loses Obsidian Sync features; flaky over bad WiFi | live demo / brief session |

---

## Option A — Vault as its own GitHub remote (recommended)

### One-time setup on server

1. Create a private repo on GitHub, e.g. `triquang26/myproject-vault`.
2. On the server:

   ```bash
   cd ~/myproject/experiments
   git remote add origin git@github.com:triquang26/myproject-vault.git
   git push -u origin main
   ```

### Auto-push after every vault commit (optional but nice)

Add a vault post-commit hook so you never forget to push:

```bash
cat >~/myproject/experiments/.git/hooks/post-commit <<'EOF'
#!/usr/bin/env bash
# Push vault to origin. Silent on failure (offline OK).
git push origin main --quiet 2>/dev/null || true
EOF
chmod +x ~/myproject/experiments/.git/hooks/post-commit
```

Now every `/exp-new`, `/exp-branch`, `/exp-record`, `/exp-link` on the server auto-pushes the vault.

### On your laptop

```bash
git clone git@github.com:triquang26/myproject-vault.git ~/vaults/myproject
open -a Obsidian ~/vaults/myproject   # macOS — opens as Obsidian vault
```

To refresh, just `git pull` in `~/vaults/myproject` — or wire a 10-second LaunchAgent:

```xml
<!-- ~/Library/LaunchAgents/com.you.vault-pull.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>            <string>com.you.vault-pull</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string><string>-c</string>
    <string>cd ~/vaults/myproject &amp;&amp; git pull --ff-only --quiet</string>
  </array>
  <key>StartInterval</key>    <integer>30</integer>   <!-- every 30 s -->
  <key>RunAtLoad</key>        <true/>
</dict>
</plist>
```

Load: `launchctl load ~/Library/LaunchAgents/com.you.vault-pull.plist`

Obsidian's file watcher will pick up new files automatically.

---

## Option B — rsync (no GitHub needed)

### Pull manually

```bash
rsync -avz --delete \
  user@server:~/myproject/experiments/ \
  ~/vaults/myproject/
```

Then `open -a Obsidian ~/vaults/myproject`.

### Auto-pull every 30 s via launchd (macOS)

```xml
<!-- ~/Library/LaunchAgents/com.you.vault-rsync.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>            <string>com.you.vault-rsync</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/rsync</string>
    <string>-avz</string><string>--delete</string>
    <string>user@server:~/myproject/experiments/</string>
    <string>~/vaults/myproject/</string>
  </array>
  <key>StartInterval</key>    <integer>30</integer>
</dict>
</plist>
```

### Auto-pull on file change via fswatch (push side, server)

If you have `fswatch` on the server, push changes the moment they happen:

```bash
fswatch -o ~/myproject/experiments | while read; do
  rsync -avz --delete ~/myproject/experiments/ \
    laptop.local:~/vaults/myproject/
done
```

(Requires laptop reachable from server — usually needs reverse-port-forward over SSH.)

---

## Option C — SSHFS live mount

### macOS one-time

```bash
brew install --cask macfuse
brew install gromgit/fuse/sshfs-mac     # community brew tap
```

### Mount + open

```bash
mkdir -p ~/mnt/myproject-vault
sshfs user@server:~/myproject/experiments ~/mnt/myproject-vault \
  -o reconnect,ServerAliveInterval=15
open -a Obsidian ~/mnt/myproject-vault
```

### Unmount

```bash
umount ~/mnt/myproject-vault
```

Caveats:
- Every Obsidian file open hits the network. Slow on first read of each file.
- Obsidian's file watcher may misbehave over FUSE — you may need to manually reload (`Cmd+R`).
- If the SSH connection drops, Obsidian shows ghost files until you remount.

---

## Comparison: which to pick?

- **Working on this every day, multiple projects** → Option A. The 5-min GitHub setup pays for itself in week 1.
- **One-off demo, sharing with no GitHub** → Option B with manual rsync.
- **Brief live look (under 1 hour) without setup** → Option C.

---

## Reverse direction: edit on laptop, sync to server?

Possible but not the recommended flow. The skills (and atomic commits) are designed to run *where the experiment runs* (server). Edits on the laptop should be limited to:
- Reading notes
- Tweaking conclusions / wording
- Manually adding links

For those, after editing in Obsidian on the laptop:

```bash
cd ~/vaults/myproject
git add -A && git commit -m "vault: manual edits"
git push
# then on server:
cd ~/myproject/experiments && git pull
```

If you find yourself doing this often, consider running Claude Code directly on the server via SSH instead of editing in Obsidian.

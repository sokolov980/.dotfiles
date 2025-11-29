# syncfiles

Cross-platform dotfile sync tool with multi-remote support, versioned backups, hooks, selective sync, and verbose mode.

---

## Usage

```bash
syncfiles [command] [options]
```

---

## Commands

- `push` Upload local dotfiles to remote(s)

- `pull` Download dotfiles from remote(s)

- `sync` Merge changes with conflict backups

- `preview` Show rsync preview including deletions

- `diff` Show a clean diff of changed files

- `help `Display usage information

---

## Options

- `-v` Enable verbose/debug mode

- `SYNCFILES_VERBOSE` Set to `true` in environment or config to enable verbose mode

- `ENCRYPT_BACKUP` Set to `true` to encrypt local backups using GPG

- `REMOTE_HOSTS` Space-separated list of remote hosts (e.g., `"laptop.local server.example.com"`)

- `REMOTE_USER` SSH user for remote hosts

- `REMOTE_PATH` Remote sync directory (default: `$HOME/dotfiles-sync`)

- `LOCAL_PATH` Local sync directory (default: `$HOME/.dotfiles`)

- `PRE_SYNC_HOOK` Shell command(s) to run before sync

- `POST_SYNC_HOOK` Shell command(s) to run after sync

- `.syncfiles_exclude` File listing patterns to exclude from sync

- `.syncfiles_include` Optional file listing specific files/folders to include

---

## Features

- Multi-remote support

- Versioned local backups

- Optional encrypted backups using GPG

- Pre/post-sync hooks

- Selective sync using include/exclude files

- Dry-run previews and clean diffs

- Multi-remote conflict detection

- Conflict summary after `sync` showing files backed up with `.conflict` suffix

- Optional verbose mode

- Executable from any terminal if symlinked to `~/bin`

---

## Multi-Remote Conflict Summary

After running:

```bash
syncfiles sync
```

If conflicts occur, files that were modified on multiple remotes are saved locally with the `.conflict` suffix:

```bash
.conflict summary:
.local_conflict/file1.conf.conflict
.local_conflict/file2.zsh.conflict
```

This allows you to manually inspect and merge changes if needed.

---

## Examples

```bash
# Synchronize local changes with all configured remotes
syncfiles sync

# Push local dotfiles to all remotes with verbose output
syncfiles push -v

# Pull remote dotfiles to local machine
syncfiles pull

# Preview changes without applying them
syncfiles preview

# List files that would change (dry run)
syncfiles diff

# Enable verbose mode via environment variable
SYNCFILES_VERBOSE=true syncfiles sync
```

---

## Notes

- Ensure the script is executable (`chmod +x syncfiles`) and in your PATH or symlinked via `~/bin`.

- Add export `PATH="$HOME/bin:$PATH"` to your shell configuration if using the symlink method.

- Optional configuration files (`.syncfiles.conf`, `.syncfiles_exclude`, `.syncfiles_include`) allow flexible customization without editing the script.

---

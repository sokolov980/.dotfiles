# deepwork

A terminal-based productivity tool that enables focused work sessions.  

---

## Usage

```bash
./deepwork.sh
```

Follow the interactive prompts to configure your session.

---

## Features

- **Website blocking:** Temporarily block distracting sites by modifying `/etc/hosts`.

- **Do Not Disturb (DND):** Enable system-wide DND mode during sessions.

- **Custom soundtrack:** Play a looping mp3 file with `mpv` during your session.

- **Pomodoro support:** Configurable work/break intervals and rounds.

- **Countdown timer:** Pre-session countdown to prepare yourself.

- **ASCII completion art:** Visual confirmation when a session ends.

- **Automatic cleanup:** Restores `/etc/hosts` and disables DND after session.

- **Interruptible:** Press a key during startup countdown to cancel session safely.

---

## Prompts

- **Session duration:** Enter number of hours (e.g., 1.5)

- **Play soundtrack:** Yes/No (optionally provide path to an mp3 file)

- **Websites to block:** Comma-separated list (e.g., x.com, youtube.com)

- **Enable Pomodoro:** Yes/No (if yes, configure work minutes, break minutes, and number of rounds)

---

## Examples

```bash
# Start a 1-hour deep work session
./deepwork.sh
```

During prompts:

```yaml
How long (hours, e.g. 1.5): 1
Play soundtrack? (y/n): y
Path to custom mp3 file: ~/Music/focus.mp3
Websites to block (comma-separated): facebook.com,youtube.com
Enable Pomodoro? (y/n): y
Work minutes (e.g., 25): 25
Break minutes (e.g., 5): 5
Number of Pomodoro rounds: 4
```

The session will:

- Block specified websites

- Enable DND mode

- Play your soundtrack (if provided)

- Run Pomodoro timers

- Display an ASCII completion message at the end

- Restore websites and DND settings automatically

---

## Notes

- Requires `mpv` installed for soundtrack playback (optional).

- Website blocking modifies `/etc/hosts`, so `sudo` permissions are required.

- DND scripts (`enable_dnd.sh` / `disable_dnd.sh`) must exist and be executable for system notifications control.

- Press any key during the startup countdown to cancel the session safely.

- Cleanup is automatic on exit to restore original system settings.

---

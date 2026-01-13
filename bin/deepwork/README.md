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

- **Do Not Disturb (DND):** Enable system-wide DND mode during sessions using your assigned macOS shortcut.

- **Custom soundtrack:** Play a looping mp3 file with `mpv` during your session.

- **Pomodoro support:** Configurable work, short break, and long break intervals with optional rounds. Defaults:
  - Work: 25 minutes
  - Short break: 5 minutes
  - Long break: 15 minutes
  - Rounds before long break: 4

- **Countdown timer:** Pre-session countdown to prepare yourself.

- **ASCII completion art:** Visual confirmation when a session ends.

- **Automatic cleanup:** Restores `/etc/hosts` and disables DND after session.

- **Interruptible:** Press a key during the startup countdown to cancel session safely.

- **Zsh fallback timer:** If `ArtTime` is unavailable, uses a built-in Zsh timer with “time remaining” display.

---

## Prompts

- **Session duration:** Enter number of hours (e.g., 1.5).

- **Play soundtrack:** Yes/No (optionally provide path to an mp3 file).

- **Websites to block:** Comma-separated list (e.g., x.com, youtube.com).

- **Enable Pomodoro:** Yes/No. If yes, you can use default or custom settings for:
  - Work minutes
  - Short break minutes
  - Long break minutes
  - Rounds before long break

---

## Examples

### Normal Session

```bash
# Start a 1-hour deep work session
./deepwork.sh
```

During prompts:

```yaml
How long (hours, e.g. 1.5): 1
Play soundtrack? (y/n): y
Path to custom mp3 file: ~/Music/focus.mp3
Websites to block (comma-separated): x.com, youtube.com, instagram.com, amazon.com
Enable Pomodoro? (y/n): y
Use default Pomodoro settings? (y/n): n
Work minutes (default 25): 25
Short break minutes (default 5): 5
Long break minutes (default 15): 15
Rounds before long break (default 4): 4
```

The session will:

- Block specified websites

- Enable DND mode via your shortcut

- Play your soundtrack (if provided)

- Run Pomodoro timers with proper spacing and “time remaining”

- Display an ASCII completion message at the end

- Restore websites and DND settings automatically

---

## Quick Test Session (1–2 Minutes)

```bash
./deepwork.sh
```

During prompts:

```yaml
How long (hours, e.g. 1.5): 0.05       # ~3 minutes total
Play soundtrack? (y/n): n
Websites to block (comma-separated): x.com, youtube.com
Enable Pomodoro? (y/n): y
Use default Pomodoro settings? (y/n): n
Work minutes (default 25): 1
Short break minutes (default 5): 1
Long break minutes (default 15): 1
Rounds before long break (default 4): 1
```

Expected behavior:

**1.** **Countdown:** 10… 9… 8… 7… 6… 5… 4… 3… 2… 1…

**2.** **DND** is enabled automatically after countdown.

**3.** **Focus / Break timers** appear with proper spacing, e.g.:

```bash
Focus (1) | time remaining 00:45  
Short Break (1/1) | time remaining 00:15  
Focus (2) | time remaining 00:45  
Long Break (1/1) | time remaining 00:25  
```

**4.** **Post-timer prompts** allow:  
   - `ENTER` → continue  
   - `e` → extend +5 minutes  
   - `q` → quit session  

**5.** **Cleanup** at the end restores:  
   - `/etc/hosts` (unblocks websites)  
   - DND disabled automatically  
   - Music stopped (if used)  
   - ASCII completion art displayed

✅ Quick way to verify that **all features work correctly** in just a few minutes.

---

## Notes

- Requires `mpv` installed for soundtrack playback (optional).

- Website blocking modifies `/etc/hosts`, so `sudo` permissions are required.

- DND scripts (`enable_dnd.sh` / `disable_dnd.sh`) must exist, be executable, and you must grant **Terminal accessibility and automation permissions** to control System Events.

- Press any key during the startup countdown to cancel the session safely.

- Cleanup is automatic on exit to restore original system settings.

- If `ArtTime` is not installed, deepwork uses a built-in Zsh timer with “time remaining” display.

---


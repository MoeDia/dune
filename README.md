<div align="center">

# dune

**A tight, fast, private macOS — set up in one command.**

Coral on charcoal · square windows · no Liquid Glass · no Apple bloat · no surprise updates

<img src="docs/preview-2.png" alt="Ghostty with herdr, Neovim and Claude Code" width="100%">

</div>

## Install

On a **fresh** macOS 26 (Tahoe) Mac, Apple silicon:

```bash
git clone https://github.com/MoeDia/dune.git && zsh dune/mac-setup.sh
```

That's it. You'll only ever **click a button or type your password** — the script does the rest, then offers to reboot. Afterwards:

```bash
zsh dune/mac-setup.sh --check     # confirms everything, changes nothing
```

> Want a wallpaper? Drop any `wallpaper.png` next to `mac-setup.sh` before running. Without one you get plain charcoal.

## What you get

| | |
|---|---|
| **Look** | Dark, coral accent, square window corners, Increase Contrast, no transparency, Commit Mono everywhere |
| **Bars** | Menu bar and Dock auto-hide · Dock on the left, small, smooth · clock with seconds, nothing else |
| **Windows** | [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling with gaps · AltTab · Maccy clipboard |
| **Terminal** | Ghostty · zsh with suggestions & highlighting · fzf, zoxide, eza, bat, ripgrep, fd, btop, lazygit, delta |
| **Code** | Neovim (no plugins, own theme) · herdr · Claude Code · git · gh · mise · Colima + docker |
| **Browser** | Firefox, themed and trimmed · uBlock Origin + Proton Pass · DRM on · telemetry off |
| **Media** | mpv with every codec, HDR, smooth motion, streaming via yt-dlp · Transmission · LocalSend · Keka |
| **Privacy** | ~115 Apple background services off (Siri, Apple Intelligence, analytics, ads, iCloud sync, Game Mode…) · Apple telemetry blocked |
| **Security** | Firewall + stealth · LuLu outbound firewall · FileVault · no SSH / sharing / guest |
| **Speed** | No animations, More Space display, raised file limits, Spotlight skips caches and build folders |
| **Updates** | Nothing updates by itself. Run `update` when *you* want: apps, tools, malware definitions, macOS list |

<img src="docs/preview-6.png" alt="lazygit, fastfetch and the shell" width="100%">

## Cheat sheet

The essentials — the full one lands in `~/quickstart.html` after setup.

| Keys | |
|---|---|
| `⌥ H J K L` · `⌥⇧ H J K L` | focus · move windows |
| `⌥ 1–5` · `⌥⇧ 1–5` | switch · send to workspace |
| `⌘ D` · `⇧⌘ D` | split terminal right · down |
| `⌃ R` · `cd proj` | fuzzy history · jump to any folder |
| `⇧⌘ C` · `⌥ ⇥` | clipboard history · window switcher |
| `update` | update everything, by hand |

## Make it yours

Everything installed lives in two lists at the top of [`mac-setup.sh`](mac-setup.sh) — `CASKS` and `FORMULAE`. Add, remove, re-run. Personal shell tweaks go in `~/.zshrc.local`, which is never touched.

## Undo

```bash
zsh dune/mac-setup.sh --undo
```

Turns Apple services back on and removes the hosts block, Firefox policies, square corners, Spotlight exclusions and file limits.

<div align="center"><sub>MIT · built for a fresh Mac · safe to re-run</sub></div>

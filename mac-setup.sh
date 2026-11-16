#!/bin/zsh
# mac-setup.sh — a tight, fast, private macOS · coral on charcoal ("dune")
#
#   zsh mac-setup.sh           set up this Mac (fresh install; safe to re-run)
#   zsh mac-setup.sh --check   checklist only, changes nothing (run once after the reboot)
#   zsh mac-setup.sh --undo    revert services, hosts block, Firefox policies, corners, Spotlight, limits
#
# Keep it next to wallpaper.png and quickstart.html. Full log: ~/mac-setup.log
set -u
setopt nullglob
exec > >(tee -a ~/mac-setup.log) 2>&1
print "\n═══ mac-setup ${1:-run} · $(date "+%Y-%m-%d %H:%M:%S") ═══"
SECONDS=0

C_ACCENT="%F{203}"; C_RESET=%f              # 256-colour coral: safe in Terminal.app
say()  { print -P "${C_ACCENT}▸${C_RESET} $1"; }        # progress line
warn() { print -P "%F{214}!%f $1"; FAILS+=("$1"); }    # remembered for the summary
FAILS=()

[[ $EUID -eq 0 ]] && { echo "Run as your user, not root."; exit 1; }
LOCK=/tmp/mac-setup.lock
if ! mkdir $LOCK 2>/dev/null; then
  kill -0 "$(cat $LOCK/pid 2>/dev/null)" 2>/dev/null && { echo "mac-setup is already running."; exit 1; }
  rm -rf /tmp/mac-setup.lock; mkdir $LOCK                        # leftover from a killed run
fi
print $$ > $LOCK/pid
trap 'rm -rf /tmp/mac-setup.lock' EXIT
trap 'print -P "\n%F{214}Stopped.%f Safe to re-run — every step skips what is already done."; exit 130' INT TERM

# ── Settings: what gets installed (edit here) ─────────────────────────────────
CASKS=(ghostty firefox lulu claude-code localsend transmission desktoppr
       font-commit-mono maccy keka alt-tab nikitabobko/tap/aerospace)
FORMULAE=(herdr neovim git duti defaultbrowser ripgrep fd displayplacer
          fzf zoxide eza bat git-delta lazygit btop gh jq fastfetch mise
          zsh-autosuggestions zsh-syntax-highlighting colima docker docker-compose ffmpeg yt-dlp)
APPS=(Ghostty Firefox mpv LuLu LocalSend Transmission AeroSpace Maccy Keka AltTab)          # checked in /Applications
BINS=(claude herdr nvim git rg fd fzf zoxide eza bat delta lazygit btop gh jq fastfetch mise colima docker ffmpeg yt-dlp mpv)  # checked on PATH

# ── Apple background services to switch off ───────────────────────────────────
# Each is disabled in launchd's override database (works with SIP on, survives
# reboots and updates, fully reversible:  zsh mac-setup.sh --undo).
# Kept ON deliberately: CloudKit (cloudd, XProtect updates), Apple account, App Store + softwareupdated (manual
# updates), Spotlight, mobileassetd, media keys (mediaremoted), clipboard sharing daemons, logging (diagnosticd),
# game controllers (gamecontrollerd), power management (coreduetd), Photos library.
SERVICES=(
  # Game Mode, Game Center, game overlay
  com.apple.gamepolicyd com.apple.GamePolicyAgent com.apple.GameOverlayUI com.apple.gamed com.apple.gamesaved
  # Siri
  com.apple.Siri.agent com.apple.assistantd com.apple.assistant_service com.apple.assistant_cdmd
  com.apple.siriactionsd com.apple.siriinferenced com.apple.siriknowledged com.apple.sirittsd com.apple.SiriTTSTrainingAgent
  # Apple Intelligence
  com.apple.intelligenceplatformd com.apple.intelligencecontextd com.apple.intelligenceflowd
  com.apple.intelligencetasksd com.apple.generativeexperiencesd com.apple.callintelligenced
  # Suggestions, knowledge graph, Spotlight web results
  com.apple.suggestd com.apple.parsecd com.apple.parsec-fbf com.apple.knowledge-agent com.apple.knowledgeconstructiond
  com.apple.spotlightknowledged com.apple.spotlightknowledged.importer com.apple.spotlightknowledged.updater
  # Analytics / telemetry
  com.apple.analyticsd com.apple.analyticsagent com.apple.audioanalyticsd com.apple.wifianalyticsd
  com.apple.ecosystemanalyticsd com.apple.geoanalyticsd com.apple.inputanalyticsd
  com.apple.osanalytics.osanalyticshelper com.apple.diagnosticspushd com.apple.feedbackd
  # Ads
  com.apple.ap.promotedcontentd com.apple.ap.adprivacyd
  # Photo/video scanning (heavy CPU on fresh installs)
  com.apple.photoanalysisd com.apple.mediaanalysisd com.apple.cloudphotod com.apple.mediastream.mstreamd
  # Apps you won't use: News, Stocks, Weather, Home, Tips, Maps sync, Translate, widgets
  com.apple.newsd com.apple.financed com.apple.weatherd com.apple.homed com.apple.homeenergyd com.apple.homeeventsd
  com.apple.tipsd com.apple.Maps.mapssyncd com.apple.Maps.pushdaemon com.apple.maps.destinationd
  com.apple.translationd com.apple.chronod
  # Screen Time / Family
  com.apple.ScreenTimeAgent com.apple.ScreenTimeSettingsAgent com.apple.familycircled com.apple.familycontrols
  com.apple.FamilyControlsAgent com.apple.familycontrols.useragent com.apple.familynotificationd
  # Remote access (hardening)
  com.apple.screensharing com.apple.screensharing.agent com.apple.screensharing.MessagesAgent com.apple.screensharing.menuextra
  # iCloud sync + notifications (no iCloud account here)
  com.apple.bird com.apple.iCloudNotificationAgent com.apple.iCloudUserNotifications com.apple.icloudmailagent
  com.apple.icloudwebd com.apple.itunescloudd
  # Find My / AirTag network
  com.apple.findmymac com.apple.findmymacmessenger com.apple.icloud.findmydeviced com.apple.icloud.findmydeviced.findmydevice-user-agent
  com.apple.icloud.searchpartyd com.apple.icloud.searchpartyuseragent com.apple.findmy.findmybeaconingd com.apple.findmy.findmylocateagent
  # Music, Safari, Messages/FaceTime/phone, Wallet, Mail, Notes sync
  com.apple.amp.mediasharingd com.apple.musicd
  com.apple.SafariBookmarksSyncAgent com.apple.SafariNotificationAgent com.apple.SafariLaunchAgent com.apple.Safari.PasswordBreachAgent
  com.apple.imagent com.apple.facetimemessagestored com.apple.callhistoryd com.apple.CallHistorySyncHelper
  com.apple.CallHistoryPluginHelper com.apple.telephonyutilities.callservicesd com.apple.passd
  com.apple.email.maild com.apple.notes.exchangenotesd com.apple.contacts.donation-agent
  # Continuity extras: Sidecar, Continuity Camera, HomeKit Thread radio
  com.apple.sidecar-relay com.apple.sidecar-hid-relay com.apple.cmio.ContinuityCaptureAgent com.apple.threadradiod
  # Usage tracking, suggestions, uploaders, update nags
  com.apple.UsageTrackingAgent com.apple.proactived com.apple.proactiveeventtrackerd com.apple.rtcreportingd
  com.apple.appleseed.seedusaged com.apple.securityuploadd com.apple.DiagnosticsReporter com.apple.gkreport
  com.apple.bosreporter com.apple.pluginkit.pkreporter com.apple.signpost.signpost_reporter
  com.apple.SoftwareUpdateNotificationManager com.apple.textunderstandingd com.apple.wifivelocityd
)
# Folders Spotlight should never crawl: caches, toolchains, package stores, build trees.
# Applications, Documents, Desktop, Downloads and Pictures stay searchable.
SPOTLIGHT_SKIP=(
  $HOME/Library/Caches $HOME/Library/Developer $HOME/Library/Logs $HOME/Library/Containers/com.apple.mediaanalysisd
  "$HOME/Library/Application Support/Firefox" $HOME/.cache $HOME/.local $HOME/.npm $HOME/.cargo $HOME/.rustup
  $HOME/.config $HOME/code /opt/homebrew /usr/local
)
toggle_services() { # $1 = disable|enable
  for s in $SERVICES; do
    for d in system gui/$UID; do
      sudo launchctl $1 $d/$s 2>/dev/null
      [[ $1 == disable ]] && sudo launchctl bootout $d/$s 2>/dev/null
    done
  done
}
disable_services() { say "Disabling ${#SERVICES} Apple background services"; toggle_services disable; }
# ── Shared paths and helpers (setup, --check, --undo) ─────────────────────────
FIREWALL=/usr/libexec/ApplicationFirewall/socketfilterfw
SPOTLIGHT_CFG=/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist
PLISTBUDDY=/usr/libexec/PlistBuddy
FF_BIN=/Applications/Firefox.app/Contents/MacOS/firefox
FF_ROOT=~/Library/Application\ Support/Firefox
ff_profile() {   # the profile Firefox actually uses: installs.ini, then profiles.ini, then a name guess
  local p ini
  for ini in "$FF_ROOT/installs.ini" "$FF_ROOT/profiles.ini"; do
    [[ -f $ini ]] || continue
    p=$(awk -F= '/^Default=Profiles\//{print $2; exit}' "$ini")
    [[ -n $p && -d $FF_ROOT/$p ]] && { print -r -- "$FF_ROOT/$p"; return; }
  done
  for p in "$FF_ROOT"/Profiles/*.default-release(N/) "$FF_ROOT"/Profiles/*.default*(N/); do print -r -- $p; return; done
}
more_space() {
  displayplacer list 2>/dev/null | awk '
    /^Persistent screen id:/ { id=$4; builtin=0 }
    /^Type: .*built in/      { builtin=1 }
    builtin && /scaling:on/ {
      split($3,r,":"); split(r[2],wh,"x"); split($4,h,":")
      if (wh[1] > bw || (wh[1]==bw && h[2] > bh)) { bw=wh[1]; bres=r[2]; bh=h[2]; bid=id }
    }
    END { if (bid) printf "id:%s res:%s hz:%s color_depth:8 enabled:true scaling:on origin:(0,0) degree:0\n", bid, bres, bh }'
}
pass()  { print -P "  %F{114}✓%f $1"; }
check() { local label=$1; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else warn "$label"; fi; }
run_checks() {   # read-only checklist — reports, changes nothing
  say "Checking"
  for a in $APPS; do check "$a installed" test -d "/Applications/$a.app"; done
  for b in $BINS; do check "$b on PATH" command -v $b; done
  check "Firefox policies"            test -f /Library/Preferences/org.mozilla.firefox.plist
  check "Firewall on"                 sh -c "$FIREWALL --getglobalstate | grep -qi 'enabled'"
  check "Firewall stealth mode"       sh -c "$FIREWALL --getstealthmode | grep -qi 'on'"
  check "FileVault on"                sh -c "fdesetup isactive | grep -q true"
  check "Game overlay disabled"       sh -c "launchctl print-disabled gui/$UID | grep -q '\"com.apple.GameOverlayUI\" => disabled'"
  check "Increase Contrast on"        sh -c "defaults read com.apple.universalaccess increaseContrast | grep -q 1"
  check "Commit Mono font"            sh -c "ls ~/Library/Fonts/CommitMono* /Library/Fonts/CommitMono* 2>/dev/null | grep -q ."
  check "Apple hosts block"           grep -q '# >>> mac-setup' /etc/hosts
  check "Game Mode daemon disabled"   sh -c "launchctl print-disabled system | grep -q '\"com.apple.gamepolicyd\" => disabled'"
  check "Game Mode agent disabled"    sh -c "launchctl print-disabled gui/$UID | grep -q '\"com.apple.GamePolicyAgent\" => disabled'"
  [[ ${AFTER_REBOOT:-0} == 1 ]] && check "Game Mode not running"       sh -c "! pgrep -x gamepolicyd && ! pgrep -x GamePolicyAgent && ! pgrep -x GameOverlayUI"
  check "Clock shows seconds"         sh -c "defaults read com.apple.menuextra.clock ShowSeconds | grep -q 1"
  check "Menu bar auto-hides"         sh -c "defaults read -g _HIHideMenuBar | grep -q 1"
  check "Dock auto-hides"             sh -c "defaults read com.apple.dock autohide | grep -q 1"
  check "Dock on the left"            sh -c "defaults read com.apple.dock orientation | grep -q left"
  check "Open-file limit raised"      sh -c "launchctl limit maxfiles | grep -q 65536"
  check "macOS auto-updates off"      sh -c "defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled | grep -q 0"
  check "Accessibility (no glass)"    sh -c "defaults read com.apple.universalaccess reduceTransparency | grep -q 1"
  check "Square window corners"       sh -c "defaults read -g NSConvolutionOverride1 | grep -q 0.01 && defaults read -g NSConvolutionOverride2 | grep -q 0.01"
  check "Spotlight exclusions"        sudo sh -c "/usr/libexec/PlistBuddy -c 'Print :Exclusions' $SPOTLIGHT_CFG | grep -q Caches"
  TARGET_RES=${"$(more_space 2>/dev/null)"#*res:}; TARGET_RES=${TARGET_RES%% *}
  check "More Space resolution"       sh -c "displayplacer list | grep -q 'res:$TARGET_RES .*current mode'"
  check "Wallpaper in place"          test -f ~/Pictures/wallpaper.png
  check "Firefox theme"               test -f "$(ff_profile)/chrome/userChrome.css"
  local total=$(( ${#FAILS} )); (( total )) && print -P "  %F{214}$total need attention%f" || print -P "  %F{114}all good%f"
}

# ── Options: --check · --undo · --help ────────────────────────────────────────
case ${1:-} in
  --undo|--undo-services)
    sudo -v || exit 1
    toggle_services enable
    sudo sed -i '' '/# >>> mac-setup/,/# <<< mac-setup/d' /etc/hosts
    sudo rm -f /Library/Preferences/org.mozilla.firefox.plist
    sudo launchctl bootout system/local.maxfiles 2>/dev/null; sudo rm -f /Library/LaunchDaemons/local.maxfiles.plist
    chflags nohidden ~/Movies ~/Music ~/Public 2>/dev/null
    defaults delete -g NSConvolutionOverride1 2>/dev/null; defaults delete -g NSConvolutionOverride2 2>/dev/null
    for x in ${SPOTLIGHT_SKIP[@]}; do
      i=0; while v=$(sudo /usr/libexec/PlistBuddy -c "Print :Exclusions:$i" $SPOTLIGHT_CFG 2>/dev/null); do
        [[ $v == $x ]] && sudo /usr/libexec/PlistBuddy -c "Delete :Exclusions:$i" $SPOTLIGHT_CFG || ((i++)); done
    done
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
    echo "Undone: services, hosts block, Firefox policies, square corners, Spotlight exclusions. Reboot."
    exit 0;;
  --check)
    BREW=/opt/homebrew; [[ -x $BREW/bin/brew ]] || BREW=/usr/local
    eval "$($BREW/bin/brew shellenv 2>/dev/null)"; sudo -v || exit 1
    AFTER_REBOOT=1; run_checks; exit 0;;
  -h|--help) print "usage: zsh mac-setup.sh [--check | --undo]
  (none)   set up this Mac (safe to re-run)
  --check  re-run the checklist only, change nothing
  --undo   switch Apple services back on; remove the hosts block, Firefox policies, square corners,
           Spotlight exclusions, file-limit daemon; unhide Movies/Music/Public (other settings stay)"; exit 0;;
  "") ;;
  *) echo "unknown option: $1"; exit 1;;
esac
# ── 0. Preflight: macOS, network, power, disk, Full Disk Access, sudo ─────────
say "macOS $(sw_vers -productVersion) · $(uname -m)"
(( ${$(sw_vers -productVersion)%%.*} >= 26 )) || print -P "%F{214}!%f Written for macOS 26+. Older versions: most settings still apply."
for u in https://formulae.brew.sh https://github.com; do curl -fsS --max-time 10 -o /dev/null $u || { echo "Can't reach $u — check the connection and re-run."; exit 1; }; done
pmset -g batt | grep -q "AC Power" || print -P "%F{214}!%f On battery — plug in; large downloads ahead."
caffeinate -dimsu -w $$ &                                    # no sleep while running
FREE_GB=$(( $(df -k / | awk 'NR==2{print $4}') / 1048576 ))
(( FREE_GB >= 15 )) || { echo "Only ${FREE_GB} GB free — need 15 GB. Free space and re-run."; exit 1; }

# Full Disk Access for the terminal running this script (macOS blocks accessibility
# settings and the Spotlight config without it — and fails silently).
has_full_disk_access() { defaults write com.apple.universalaccess _macsetup_probe -bool true 2>/dev/null \
           && defaults delete com.apple.universalaccess _macsetup_probe 2>/dev/null; }
RESUME_AGENT=~/Library/LaunchAgents/local.mac-setup.resume.plist; RESUME_CMD=~/.mac-setup-resume.command
remove_resume_agent() { launchctl bootout gui/$UID/local.mac-setup.resume 2>/dev/null; rm -f $RESUME_AGENT $RESUME_CMD; }
if ! has_full_disk_access; then
  case ${TERM_PROGRAM:-} in
    ghostty) TERM_APP=Ghostty; TERM_APP_PATH=/Applications/Ghostty.app ;;
    iTerm.app) TERM_APP=iTerm; TERM_APP_PATH=/Applications/iTerm.app ;;
    *) TERM_APP=Terminal; TERM_APP_PATH=/System/Applications/Utilities/Terminal.app ;;
  esac
  SELF=${0:A}
  TERM_PID=$(pgrep -oix "$TERM_APP" 2>/dev/null)
  if [[ -n $TERM_PID ]]; then WAIT_CMD="while kill -0 $TERM_PID 2>/dev/null; do sleep 1; done"     # this exact process
  else WAIT_CMD="while pgrep -ixq $TERM_APP; do sleep 1; done"; fi
  # resume plan first: whenever the terminal quits (our restart OR the "Quit & Reopen" button),
  # launchd reopens it running this script again
  print -r -- "#!/bin/zsh
exec /bin/zsh ${(q)SELF}" > $RESUME_CMD; chmod +x $RESUME_CMD
  if [[ $TERM_APP == Ghostty ]]; then OPEN_CMD="open -na Ghostty --args -e /bin/zsh ${(q)SELF}"
  else OPEN_CMD="open -a ${(q)TERM_APP} ${(q)RESUME_CMD}"; fi
  mkdir -p ~/Library/LaunchAgents
  cat > $RESUME_AGENT <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.mac-setup.resume</string>
  <key>ProgramArguments</key><array><string>/bin/zsh</string><string>-c</string>
    <string>sleep 3; $WAIT_CMD; rm -f "$RESUME_AGENT"; sleep 1; $OPEN_CMD; launchctl bootout gui/\$(id -u)/local.mac-setup.resume</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
XML
  launchctl bootstrap gui/$UID $RESUME_AGENT 2>/dev/null
  print -P "%F{214}▸%f One click needed: allow Full Disk Access for $TERM_APP."
  print   "   Switch $TERM_APP on in the window that opens (or press + and pick it from the Finder window)."
  print   "   If macOS offers “Quit & Reopen”, click it — setup continues by itself."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  open -R "$TERM_APP_PATH"
  for _ in {1..60}; do sleep 2; has_full_disk_access && break; done
  if ! has_full_disk_access; then
    print -P "%F{214}▸%f Restarting $TERM_APP to apply it — setup continues by itself."
    rm -rf /tmp/mac-setup.lock
    ( sleep 2; osascript -e "tell application \"$TERM_APP\" to quit" ) >/dev/null 2>&1 &!   # after we exit → no "terminate?" prompt
    exit 0
  fi
  print -P "%F{114}✓%f Full Disk Access on."
fi
remove_resume_agent                                   # resume agent never outlives the hand-off

# sudo once, kept alive until the script ends
sudo -v || exit 1
( while true; do sudo -n true; sleep 50; done ) 2>/dev/null & SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null; rm -rf /tmp/mac-setup.lock' EXIT
killall "System Settings" 2>/dev/null

# ── 1. Homebrew (also installs the Xcode Command Line Tools) ──────────────────
if [[ $(uname -m) == arm64 ]]; then BREW=/opt/homebrew; else BREW=/usr/local; fi
if [[ ! -x $BREW/bin/brew ]]; then
  say "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "Homebrew failed"; exit 1; }
fi
eval "$($BREW/bin/brew shellenv)"
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1
brew analytics off

# ── 2. Apps ───────────────────────────────────────────────────────────────────
say "Installing apps"
retry() { local i; for i in 1 2 3; do "$@" && return 0; print "  retry $i/3: $*"; sleep $((i*5)); done; return 1; }
brew update --quiet || true
export HOMEBREW_DOWNLOAD_CONCURRENCY=auto                     # fetch several bottles at once
missing_casks=(); for c in $CASKS;    do brew list --cask ${c:t} &>/dev/null || missing_casks+=$c; done
missing_formulae=(); for f in $FORMULAE; do brew list ${f:t}        &>/dev/null || missing_formulae+=$f; done
(( ${#missing_formulae} )) && { brew install ${missing_formulae[@]} || true; }
(( ${#missing_casks} )) && { brew install --cask ${missing_casks[@]} || true; }
for f in $missing_formulae; do brew list ${f:t} &>/dev/null        || retry brew install $f        || warn "formula ${f:t} failed"; done
for c in $missing_casks; do brew list --cask ${c:t} &>/dev/null || retry brew install --cask $c || warn "cask ${c:t} failed"; done
# mpv: Homebrew disabled the stolendata cask (not notarised). Same official build, fetched
# directly and checksum-pinned (curl downloads carry no quarantine flag, so it just runs).
MPV_URL=https://laboratory.stolendata.net/~djinn/mpv_osx/mpv-arm64-0.40.0.tar.gz
MPV_SHA=3170fb709defebaba33e9755297d70dc3562220541de54fc3d494a8309ef1260
if [[ ! -d /Applications/mpv.app ]]; then
  if [[ $(uname -m) == arm64 ]]; then
    MPV_TMP=$(mktemp -d)
    if retry curl -fsSL -o $MPV_TMP/mpv.tgz $MPV_URL && print "$MPV_SHA  $MPV_TMP/mpv.tgz" | shasum -a 256 -c --status; then
      tar -xzf $MPV_TMP/mpv.tgz -C $MPV_TMP && ditto $MPV_TMP/mpv-*/mpv.app /Applications/mpv.app || warn "mpv unpack failed"
    else warn "mpv download failed or checksum mismatch — not installed"; fi
    rm -rf "${MPV_TMP:?}"
  else brew install mpv || warn "mpv failed"; fi
fi
[[ -x /Applications/mpv.app/Contents/MacOS/mpv ]] && ln -sf /Applications/mpv.app/Contents/MacOS/mpv $BREW/bin/mpv
# make LaunchServices see the new apps right away (defaults, Dock, `open -a`)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for a in /Applications/*.app; do $LSREGISTER -f "$a" 2>/dev/null; done

# ── 3. Remove Apple apps ──────────────────────────────────────────────────────
# Only the removable ones — Safari, Mail, Music and co. live on the sealed system volume.
say "Removing Apple apps"
for a in GarageBand iMovie Keynote Numbers Pages; do
  [[ -d "/Applications/$a.app" ]] || continue
  sudo rm -rf "/Applications/$a.app" 2>/dev/null; [[ -d "/Applications/$a.app" ]] && warn "$a not removed — drag it to the Bin (App Management blocks scripts)"
done
sudo rm -rf "/Library/Application Support/GarageBand" "/Library/Application Support/Logic" "/Library/Audio/Apple Loops" 2>/dev/null

disable_services   # list + logic at top of file; full effect after reboot

# ── 4. Privacy and Apple network blocking ─────────────────────────────────────
say "Privacy"
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
defaults write com.apple.AdLib allowIdentifierForAdvertising -bool false
defaults write com.apple.CrashReporter DialogType -string none
CRASH_PLIST="/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist"
sudo defaults write "$CRASH_PLIST" AutoSubmit -bool false
sudo defaults write "$CRASH_PLIST" ThirdPartyDataSubmit -bool false
defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true
defaults write com.apple.Spotlight SuggestionsEnabled -bool false
defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false       # save locally, not iCloud

# Apple tracking / iCloud blocked system-wide via hosts (managed block, re-run safe).
# Not blocked on purpose: security updates, XProtect, notarization, App Store, time sync.
say "Blocking Apple telemetry + iCloud"
sudo sed -i '' '/# >>> mac-setup/,/# <<< mac-setup/d' /etc/hosts
{
  echo "# >>> mac-setup"
  for h in metrics.apple.com metrics.icloud.com metrics.mzstatic.com xp.apple.com \
    iadsdk.apple.com api-adservices.apple.com ca.iadsdk.apple.com cf.iadsdk.apple.com \
    banners.itunes.apple.com radarsubmissions.apple.com \
    stocks-data-service.apple.com news-edge.apple.com news-events.apple.com \
    weather-data.apple.com guzzoni.apple.com api.smoot.apple.com api-glb.smoot.apple.com fbs.smoot.apple.com \
    icloud.com www.icloud.com setup.icloud.com \
    keyvalueservice.icloud.com p01-keyvalueservice.icloud.com; do   # CloudKit stays open: XProtect updates use it
    echo "0.0.0.0 $h"; echo ":: $h"
  done
  echo "# <<< mac-setup"
} | sudo tee -a /etc/hosts >/dev/null
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# ── 5. Security, updates, FileVault ───────────────────────────────────────────
say "Security"
sudo $FIREWALL --setglobalstate on >/dev/null; sudo $FIREWALL --setstealthmode on >/dev/null
sudo $FIREWALL --setallowsignedapp off >/dev/null                               # downloaded apps must ask for incoming
sudo $FIREWALL --setloggingmode on >/dev/null
for a in /Applications/LocalSend.app; do [[ -d $a ]] && { sudo $FIREWALL --add $a; sudo $FIREWALL --unblockapp $a; } >/dev/null; done
sudo launchctl disable system/com.openssh.sshd 2>/dev/null; sudo launchctl bootout system/com.openssh.sshd 2>/dev/null
SWUPDATE=/Library/Preferences/com.apple.SoftwareUpdate
# Updates: nothing checks, downloads or installs by itself. Check by hand:
#   run `update` (apps, tools, malware definitions, macOS list)
for k in AutomaticCheckEnabled AutomaticDownload AutomaticallyInstallMacOSUpdates AutomaticallyInstallAppUpdates \
         CriticalUpdateInstall ConfigDataInstall; do sudo defaults write $SWUPDATE $k -bool false; done
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false
defaults write com.apple.commerce AutoUpdate -bool false
sudo softwareupdate --schedule off >/dev/null 2>&1
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
defaults -currentHost write com.apple.screensaver idleTime -int 600       # screensaver + lock after 10 min
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
spctl --status 2>/dev/null | grep -q enabled || sudo spctl --global-enable 2>/dev/null || sudo spctl --master-enable   # Gatekeeper on
sudo systemsetup -setremoteappleevents off >/dev/null 2>&1
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
sudo defaults write /Library/Preferences/com.apple.loginwindow RetriesUntilHint -int 0   # no password hints
sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null
sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true   # don't list users
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool false
sudo launchctl disable system/com.apple.smbd 2>/dev/null                # file sharing off
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true  # no Bonjour broadcast
sudo pmset -a womp 0                                                     # no wake-on-network
sudo pmset -a powernap 0                                                 # no background wakes
if ! fdesetup isactive >/dev/null; then
  say "Turning on FileVault — type your Mac password and press Enter (nothing shows while typing)"
  FV_PLIST=$(mktemp); trap 'rm -f $FV_PLIST; kill $SUDO_KEEPALIVE 2>/dev/null; rm -rf /tmp/mac-setup.lock' EXIT
  if sudo fdesetup enable -user "$USER" -outputplist > $FV_PLIST && FV_KEY=$(plutil -extract RecoveryKey raw $FV_PLIST 2>/dev/null) && [[ -n $FV_KEY ]]; then
    { print -P "\n  %F{214}FileVault recovery key:%f  $FV_KEY"          # screen only — never into the log
      print   "  Write it down or put it in Proton Pass now. It is not saved anywhere else."; } > /dev/tty
    [[ -t 0 ]] && read -s "?  Press Enter once it's saved… " < /dev/tty && print > /dev/tty; FV_KEY=
    rm -f $FV_PLIST
  elif fdesetup isactive >/dev/null; then          # enabled, but the key wasn't parsed: show the raw output
    { print -P "\n  %F{214}FileVault is ON — your recovery key is in this output:%f"; cat $FV_PLIST; } > /dev/tty
    [[ -t 0 ]] && read -s "?  Press Enter once it's saved… " < /dev/tty && print > /dev/tty
    rm -f $FV_PLIST
  else rm -f $FV_PLIST; warn "FileVault not enabled — System Settings › Privacy & Security › FileVault"; fi
fi

# ── 6. Look: charcoal + coral, square windows, wallpaper, display ─────────────
say "Theme"
defaults write -g AppleInterfaceStyle -string Dark
defaults write -g AppleAccentColor -int 0                              # red — closest system accent to the coral
defaults write -g AppleHighlightColor -string "1.000 0.690 0.640 Other" # light coral #FFB0A3
defaults write -g NSSplitViewItemSidebarDefaultsToFloatingAppearance -bool false
defaults delete -g NSConvolutionOverrides 2>/dev/null                    # old key from the video: no effect
defaults write -g NSConvolutionOverride1 -float 0.01                   # square windows, sheets, alerts
defaults write -g NSConvolutionOverride2 -float 0.01                   # square panels, utility windows
defaults write com.apple.universalaccess increaseContrast -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true
defaults write com.apple.universalaccess reduceMotion -bool false   # keep real Dock minimize/open motion
defaults write -g AppleIconAppearanceTheme -string RegularDark         # full-colour icons on dark tiles
defaults write -g AppleShowScrollBars -string WhenScrolling
defaults write -g AppleWindowTabbingMode -string manual               # no surprise tabs
defaults write com.apple.HIToolbox AppleFnUsageType -int 0              # 🌐 key does nothing
defaults write -g NSTableViewDefaultSizeMode -int 1                    # small sidebar icons everywhere
defaults write -g com.apple.sound.uiaudio.enabled -int 0               # no UI sound effects
defaults write -g com.apple.sound.beep.feedback -int 0                 # no volume-change blip
sudo nvram StartupMute=%01                                             # no boot chime
# Wallpaper: wallpaper.png from the kit folder (falls back to plain charcoal)
KIT=${0:A:h}; WALLPAPER=~/Pictures/wallpaper.png
if [[ -f $KIT/wallpaper.png ]]; then cp -f $KIT/wallpaper.png $WALLPAPER
else /usr/bin/python3 -I -c 'import sys,zlib,struct
w=h=64; row=b"\x00"+bytes([0x12,0x12,0x16])*w
c=lambda t,d:struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
open(sys.argv[1],"wb").write(b"\x89PNG\r\n\x1a\n"+c(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))+c(b"IDAT",zlib.compress(row*h))+c(b"IEND",b""))' "$WALLPAPER"
fi
DESKTOPPR=/usr/local/bin/desktoppr   # installed by its pkg here on every Mac
[[ -x $DESKTOPPR ]] && $DESKTOPPR "$WALLPAPER" && $DESKTOPPR scale fill || warn "wallpaper not set (desktoppr missing)"

# Display: built-in screen at its largest HiDPI mode ("More Space") — smaller UI, more on screen
if command -v displayplacer >/dev/null; then
  DISPLAY_MODE=$(more_space); [[ -n $DISPLAY_MODE ]] && displayplacer "$DISPLAY_MODE" || warn "More Space not set (no built-in display found)"
fi

# ── 7. Menu bar: auto-hides, clock with seconds, bare minimum ─────────────────
say "Menu bar"
defaults write -g _HIHideMenuBar -bool true                     # menu bar slides in at the top edge
defaults write -g AppleMenuBarVisibleInFullscreen -bool false
CLOCK=com.apple.menuextra.clock
defaults write $CLOCK ShowSeconds -bool true
defaults write $CLOCK Show24Hour -bool true
defaults write $CLOCK ShowDayOfWeek -bool false          # just 14:32:07
defaults write $CLOCK ShowDate -int 2
defaults write $CLOCK IsAnalog -bool false
for k in Bluetooth AirDrop Display Sound NowPlaying FocusModes ScreenMirroring UserSwitcher StageManager KeyboardBrightness; do
  defaults -currentHost write com.apple.controlcenter $k -int 24          # 24 = hidden
done
for k in Bluetooth AirDrop Display Sound NowPlaying FocusModes ScreenMirroring UserSwitcher StageManager KeyboardBrightness; do
  defaults write com.apple.controlcenter "NSStatusItem Visible $k" -bool false     # macOS 26 key
done
defaults -currentHost write com.apple.controlcenter WiFi -int 18          # 18 = shown
defaults -currentHost write com.apple.controlcenter Battery -int 18
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
defaults write com.apple.TextInputMenu visible -bool false
defaults -currentHost write -g NSStatusItemSpacing -int 8                # tighter menu bar icons
defaults -currentHost write -g NSStatusItemSelectionPadding -int 4

# ── 8. Dock: left, small, tight, auto-hides ───────────────────────────────────
say "Dock"
DOCK=com.apple.dock
defaults write $DOCK orientation -string left
defaults write $DOCK tilesize -int 30
defaults write $DOCK magnification -bool false
defaults write $DOCK autohide -bool true
defaults write $DOCK autohide-delay -float 0                  # no wait at the edge
defaults write $DOCK autohide-time-modifier -float 0.35       # quick, smooth slide
defaults write $DOCK show-recents -bool false
defaults write $DOCK show-process-indicators -bool true
defaults write $DOCK minimize-to-application -bool true
defaults write $DOCK mineffect -string scale                     # crisp, fast shrink into the Dock
defaults write $DOCK scroll-to-open -bool true                     # scroll up on an icon: show its windows
defaults write $DOCK enable-spring-load-actions-on-all-items -bool true
defaults write -g AppleActionOnDoubleClick -string Minimize       # double-click a title bar to minimize
defaults write $DOCK launchanim -bool false                      # no bouncing; app windows open instantly
defaults write $DOCK expose-animation-duration -float 0.1
defaults write $DOCK mru-spaces -bool false
for c in tl tr bl br; do defaults write $DOCK wvous-$c-corner -int 1; defaults write $DOCK wvous-$c-modifier -int 0; done   # no hot corners
defaults write $DOCK persistent-others -array
defaults write $DOCK persistent-apps -array
for app in /Applications/Ghostty.app /Applications/Firefox.app  \
           /Applications/mpv.app; do
  [[ -d $app ]] && defaults write $DOCK persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
done

# ── 9. Desktop, Finder, input ─────────────────────────────────────────────────
say "Desktop, Finder, input"
FINDER=com.apple.finder
defaults write $FINDER CreateDesktop -bool false
defaults write $FINDER DisableAllAnimations -bool true
defaults write $FINDER ShowPathbar -bool false
defaults write $FINDER ShowStatusBar -bool false
defaults write $FINDER FXPreferredViewStyle -string Nlsv
defaults write $FINDER FXDefaultSearchScope -string SCcf
defaults write $FINDER FXEnableExtensionChangeWarning -bool false
defaults write $FINDER NewWindowTarget -string PfHm
defaults write $FINDER _FXSortFoldersFirst -bool true
defaults write $FINDER FXRemoveOldTrashItems -bool true
# Finder sidebar: bare minimum (Home, Downloads, Desktop · no Recents/tags/iCloud/AirDrop)
defaults write $FINDER ShowRecentTags -bool false
defaults write $FINDER ShowSidebar -bool true
defaults write $FINDER ShowPreviewPane -bool false
defaults write $FINDER FXArrangeGroupViewBy -string Name
defaults write $FINDER WarnOnEmptyTrash -bool false
defaults write $FINDER SidebarShowingiCloudDesktop -bool false
defaults write $FINDER SidebarShowingSignedIntoiCloud -bool false
defaults write $FINDER ShowExternalHardDrivesOnDesktop -bool false
defaults write $FINDER ShowRemovableMediaOnDesktop -bool false
defaults write com.apple.sidebarlists networkbrowser -dict-add CustomListProperties '<dict><key>com.apple.NetworkBrowser.backToMyMacEnabled</key><false/><key>com.apple.NetworkBrowser.bonjourEnabled</key><false/><key>com.apple.NetworkBrowser.connectedEnabled</key><false/></dict>'
defaults write -g AppleShowAllExtensions -bool true
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
defaults write com.apple.WindowManager GloballyEnabled -bool false          # Stage Manager off
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
chflags hidden ~/Movies ~/Music ~/Public 2>/dev/null           # home shows only what you use
mkdir -p ~/Pictures/Screenshots
defaults write com.apple.screencapture location ~/Pictures/Screenshots
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture show-thumbnail -bool false
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write -g ApplePressAndHoldEnabled -bool false
for k in NSAutomaticSpellingCorrectionEnabled NSAutomaticCapitalizationEnabled NSAutomaticPeriodSubstitutionEnabled \
         NSAutomaticQuoteSubstitutionEnabled NSAutomaticDashSubstitutionEnabled; do defaults write -g $k -bool false; done
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# ── 10. Performance and Spotlight ─────────────────────────────────────────────
say "Performance"
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g NSScrollAnimationEnabled -bool false
defaults write -g QLPanelAnimationDuration -float 0
defaults write -g NSToolbarTitleViewRolloverDelay -float 0
defaults write com.apple.loginwindow TALLogoutSavesState -bool false     # don't reopen windows at login
defaults write -g NSQuitAlwaysKeepsWindows -bool false
sudo tmutil disable 2>/dev/null                                           # no TM local snapshots eating disk I/O (re-enable if you use TM)
# Less background radio/network chatter: no Handoff beacons, no AirPlay receiver listening
defaults -currentHost write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false
defaults -currentHost write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false
defaults -currentHost write com.apple.controlcenter AirplayRecieverEnabled -bool false   # (Apple's spelling)
# Higher open-file limit for dev tools (default soft limit is 256)
sudo tee /Library/LaunchDaemons/local.maxfiles.plist >/dev/null <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.maxfiles</string>
  <key>ProgramArguments</key><array><string>/bin/sh</string><string>-c</string><string>sysctl -w kern.maxfiles=524288 kern.maxfilesperproc=262144; launchctl limit maxfiles 65536 262144</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
XML
sudo chown root:wheel /Library/LaunchDaemons/local.maxfiles.plist; sudo chmod 644 /Library/LaunchDaemons/local.maxfiles.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/local.maxfiles.plist 2>/dev/null || true
# Full speed on the charger; macOS still manages battery when unplugged
sudo pmset -c lowpowermode 0
sudo pmset -a tcpkeepalive 0 2>/dev/null                                 # no network wakes while asleep
# Shell: no slow Homebrew auto-update before every install
grep -q HOMEBREW_NO_AUTO_UPDATE ~/.zprofile 2>/dev/null || echo 'export HOMEBREW_NO_AUTO_UPDATE=1' >> ~/.zprofile
# Spotlight: skip churny folders. mds reads this list at boot (it is SIP-protected, so no restart).
if sudo test -f $SPOTLIGHT_CFG; then
  sudo $PLISTBUDDY -c "Print :Exclusions" $SPOTLIGHT_CFG >/dev/null 2>&1 || sudo $PLISTBUDDY -c "Add :Exclusions array" $SPOTLIGHT_CFG
  mkdir -p ~/code ~/.cache ~/.local ~/.config
  for x in ${SPOTLIGHT_SKIP[@]}; do
    sudo $PLISTBUDDY -c "Print :Exclusions" $SPOTLIGHT_CFG 2>/dev/null | grep -qxF "    $x" || sudo $PLISTBUDDY -c "Add :Exclusions: string $x" $SPOTLIGHT_CFG
  done
sudo killall mds 2>/dev/null                 # mds reloads the list instead of writing its old copy back
else warn "Spotlight config not readable — give Terminal Full Disk Access, then re-run"; fi
for v in /Volumes/*; do [[ -L $v || $v == "/Volumes/Macintosh HD" ]] && continue; sudo mdutil -i off "$v" >/dev/null 2>&1; done

# Config files: keep a one-time backup of anything this script didn't write.
put() {   # put <path> <<EOF … EOF — writes a config file, backing up any foreign one once
  local f=$1 tmp; tmp=$(mktemp); cat > $tmp; mkdir -p ${f:h}
  if [[ -f $f ]] && ! grep -q "mac-setup" $f && ! cmp -s $tmp $f; then cp $f $f.pre-mac-setup; fi
  mv $tmp $f
}

# ── 11. Terminal, editor and tools — one palette ("dune") ─────────────────────
#   bg 121216 · surface 1a1a20 · raised 26262e · line 55555f · dim 8e8e9c · muted b0b0bd
#   text ececf1 · accent ff5f45 · keywords ff8a6b · numbers/search ffc27a · error e05a6a · green b5d18a
#   blue 6cc4f0 · pink ef9ab3 · aqua 8fd6c2
say "Terminal stack"

# Ghostty: no chrome beyond what macOS forces, flat padding, no blink, dim inactive splits
put ~/.config/ghostty/config <<'EOF'
# managed by mac-setup
font-family = CommitMono
font-size = 14
font-thicken = true
font-thicken-strength = 40
font-feature = -calt
adjust-cell-height = 12%
background = 121216
foreground = ececf1
cursor-color = ff5f45
cursor-text = 121216
cursor-style = bar
cursor-style-blink = false
selection-background = 5c1f1a
selection-foreground = fff1e6
palette = 0=1a1a20
palette = 1=e05a6a
palette = 2=b5d18a
palette = 3=ffc27a
palette = 4=6cc4f0
palette = 5=ef9ab3
palette = 6=8fd6c2
palette = 7=c9bfb3
palette = 8=8e8e9c
palette = 9=ff6f4a
palette = 10=bcd38f
palette = 11=f2bfa0
palette = 12=a0bfd8
palette = 13=e6a3b6
palette = 14=9ed6c5
palette = 15=f3ebe1
minimum-contrast = 1.1
window-padding-x = 14
window-padding-y = 10
window-padding-balance = true
window-padding-color = extend
macos-titlebar-style = transparent
macos-titlebar-proxy-icon = hidden
macos-option-as-alt = left
macos-icon = custom-style
macos-icon-frame = chrome
macos-icon-ghost-color = ff5f45
macos-icon-screen-color = 121216
unfocused-split-opacity = 0.8
unfocused-split-fill = 121216
split-divider-color = 55555f
window-inherit-working-directory = true
window-save-state = never
auto-update = off
confirm-close-surface = false
quit-after-last-window-closed = true
mouse-hide-while-typing = true
copy-on-select = clipboard
resize-overlay = never
shell-integration-features = no-cursor,sudo,title
keybind = cmd+d=new_split:right
keybind = cmd+shift+d=new_split:down
keybind = cmd+alt+left=goto_split:left
keybind = cmd+alt+right=goto_split:right
keybind = cmd+alt+up=goto_split:up
keybind = cmd+alt+down=goto_split:down
keybind = cmd+shift+enter=toggle_split_zoom
EOF

# zsh: one-line prompt — dir · branch · ❯ (red ❯ after a failed command), no right side
put ~/.zshrc <<EOF
# managed by mac-setup — personal additions go in ~/.zshrc.local
eval "\$($BREW/bin/brew shellenv)"
export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_AUTO_UPDATE=1 DISABLE_AUTOUPDATER=1
export EDITOR=nvim VISUAL=nvim PAGER=less LESS=-RFX
export CLICOLOR=1 LSCOLORS=gxfxcxdxbxegedabagacad
[[ \$TERM_PROGRAM == Apple_Terminal ]] && zmodload zsh/nearcolor   # Terminal.app: map hex colours to 256
ulimit -n 65536 2>/dev/null
autoload -Uz vcs_info compinit
_zcd=(~/.zcompdump(N.mh+24)); if (( \${#_zcd} )); then compinit; else compinit -C; fi; unset _zcd
precmd() { vcs_info; print -Pn "\e]0;%1~\a" }
zstyle ':vcs_info:git:*' formats ' %F{#8e8e9c}%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{#8e8e9c}%b%f %F{#e05a6a}%a%f'
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
setopt PROMPT_SUBST HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY AUTO_CD NO_BEEP INTERACTIVE_COMMENTS
HISTSIZE=50000 SAVEHIST=50000 HISTFILE=~/.zsh_history
PROMPT='%F{#ff5f45}%1~%f\${vcs_info_msg_0_} %(?.%F{#ffc27a}.%F{#e05a6a})❯%f '
RPROMPT=''
bindkey -e
# tools
export BAT_THEME=ansi
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout reverse --border none --info inline --prompt "❯ " --pointer "▌" --marker "▌"
  --color fg:#b0b0bd,bg:-1,hl:#ff5f45,fg+:#ececf1,bg+:#1f1f26,hl+:#ff8a6b,info:#8e8e9c,prompt:#ff5f45,pointer:#ff5f45,marker:#ffc27a,spinner:#ff5f45,header:#6cc4f0,border:#55555f'
export EZA_COLORS='di=38;2;108;196;240:ex=38;2;181;209;138:ln=38;2;143;214;194:da=38;2;133;144;171:ur=38;2;255;194;122:uw=38;2;255;122;26:ux=38;2;181;209;138'
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#55555f'
command -v zoxide >/dev/null && eval "\$(zoxide init zsh --cmd cd)"
command -v fzf    >/dev/null && source <(fzf --zsh)
command -v mise   >/dev/null && eval "\$(mise activate zsh)"
alias ls="eza --group-directories-first" ll="eza -l --git --group-directories-first" la="eza -la --git --group-directories-first"
alias tree="eza --tree --level 2" cat="bat --paging=never" lg=lazygit top=btop vim=nvim vi=nvim g=git
# manual updates — the only way anything updates on this Mac
update() {
  brew update && brew upgrade && brew upgrade --cask --greedy
  command -v mise >/dev/null && mise upgrade
  print -P "%F{#ff5f45}▸%f malware definitions (XProtect):"; sudo xprotect update 2>&1 | sed 's/^/  /'
  brew cleanup --prune=all -s
  print -P "%F{#ff5f45}▸%f macOS updates:"; softwareupdate --list 2>&1 | sed 's/^/  /'
}
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
source $BREW/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source $BREW/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null   # must stay last
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#ff8a6b'; ZSH_HIGHLIGHT_STYLES[builtin]='fg=#ff8a6b'; ZSH_HIGHLIGHT_STYLES[alias]='fg=#ff8a6b'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#e05a6a'; ZSH_HIGHLIGHT_STYLES[path]='fg=#ececf1,underline'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#b5d18a'; ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#b5d18a'
EOF

# Neovim: no plugins. Own dune colorscheme, single global statusline, no ~ filler, rounded floats
put ~/.config/nvim/init.lua <<'EOF'
-- managed by mac-setup
vim.g.mapleader = ' '
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3

local o = vim.opt
o.termguicolors = true
o.number = true; o.relativenumber = true
o.cursorline = true; o.cursorlineopt = 'both'
o.signcolumn = 'yes:1'; o.laststatus = 3; o.showmode = false; o.ruler = false
o.cmdheight = 1; o.pumheight = 10; o.scrolloff = 6; o.sidescrolloff = 8
o.fillchars = { eob = ' ', vert = '│', fold = ' ' }
o.shortmess:append('I')
o.clipboard = 'unnamedplus'; o.mouse = 'a'; o.undofile = true; o.swapfile = false
o.ignorecase = true; o.smartcase = true; o.inccommand = 'split'
o.expandtab = true; o.shiftwidth = 2; o.tabstop = 2; o.smartindent = true
o.splitright = true; o.splitbelow = true; o.wrap = false
o.updatetime = 250; o.timeoutlen = 400
pcall(function() o.winborder = 'rounded' end)

-- dune colorscheme
vim.cmd('highlight clear'); vim.g.colors_name = 'dune'
local c = { bg='#121216', s1='#1a1a20', s2='#26262e', line='#55555f', dim='#8e8e9c', muted='#b0b0bd',
  fg='#ececf1', or_='#ff5f45', amb='#ffc27a', red='#e05a6a', grn='#b5d18a', blu='#6cc4f0', pnk='#ef9ab3', aq='#8fd6c2' }
local hl = function(g, v) vim.api.nvim_set_hl(0, g, v) end
for g, v in pairs({
  Normal={fg=c.fg,bg=c.bg}, NormalFloat={fg=c.fg,bg=c.s1}, FloatBorder={fg=c.line,bg=c.s1},
  CursorLine={bg='#1f1f26'}, CursorLineNr={fg=c.or_,bold=true}, LineNr={fg=c.line}, SignColumn={bg=c.bg},
  Visual={bg='#5c1f1a'}, Search={fg=c.bg,bg=c.amb}, IncSearch={fg=c.bg,bg=c.or_}, CurSearch={fg=c.bg,bg=c.or_},
  MatchParen={fg=c.or_,bold=true,underline=true}, NonText={fg=c.line}, Whitespace={fg=c.line},
  WinSeparator={fg=c.line}, StatusLine={fg=c.muted,bg=c.s1}, StatusLineNC={fg=c.dim,bg=c.s1},
  Pmenu={fg=c.fg,bg=c.s1}, PmenuSel={fg=c.bg,bg=c.or_}, PmenuSbar={bg=c.s1}, PmenuThumb={bg=c.line},
  Comment={fg=c.dim,italic=true}, String={fg=c.grn}, Character={fg=c.grn}, Number={fg=c.amb}, Boolean={fg=c.amb},
  Constant={fg=c.amb}, Keyword={fg='#ff8a6b'}, Statement={fg='#ff8a6b'}, Conditional={fg='#ff8a6b'}, Repeat={fg='#ff8a6b'},
  Function={fg=c.blu}, Type={fg=c.aq}, Identifier={fg=c.fg}, Operator={fg=c.muted}, Delimiter={fg=c.muted},
  Special={fg=c.pnk}, PreProc={fg=c.pnk}, Title={fg=c.or_,bold=true}, Directory={fg=c.blu},
  Todo={fg=c.bg,bg=c.amb,bold=true}, Error={fg=c.red}, ErrorMsg={fg=c.red}, WarningMsg={fg=c.amb}, ModeMsg={fg=c.muted},
  DiffAdd={bg='#1f2a18'}, DiffChange={bg='#2a2216'}, DiffDelete={fg=c.red,bg='#2a1714'}, DiffText={bg='#3a2a14'},
  DiagnosticError={fg=c.red}, DiagnosticWarn={fg=c.amb}, DiagnosticInfo={fg=c.blu}, DiagnosticHint={fg=c.aq},
  ['@variable']={fg=c.fg}, ['@property']={fg=c.fg}, ['@punctuation']={fg=c.muted}, ['@markup.heading']={fg=c.or_,bold=true},
  StMode={fg=c.bg,bg=c.or_,bold=true}, StFile={fg=c.fg,bg=c.s1}, StDim={fg=c.dim,bg=c.s1},
}) do hl(g, v) end

-- statusline: MODE  file [+]                      ft · line:col
local modes = { n='NOR', i='INS', v='VIS', V='V-L', ['\22']='V-B', c='CMD', R='REP', t='TRM' }
function _G.dune_statusline()
  local m = modes[vim.fn.mode():sub(1,1)] or vim.fn.mode()
  return table.concat({ '%#StMode# ', m, ' %#StFile# %f%m', '%=%#StDim#', vim.bo.filetype, '  %l:%c ' })
end
o.statusline = '%!v:lua.dune_statusline()'

-- keys
local map = vim.keymap.set
map('n', '<Esc>', '<cmd>nohlsearch<cr>')
map('n', '<leader>e', '<cmd>Explore<cr>')
map('n', '<leader>w', '<cmd>write<cr>')
map('n', '<leader>q', '<cmd>quit<cr>')
map({ 'n', 'v' }, '<leader>y', '"+y')
vim.api.nvim_create_autocmd('TextYankPost', { callback = function() vim.hl.on_yank({ timeout = 120 }) end })
EOF

# herdr: same palette, no onboarding, quiet chrome, clipboard toasts off
put ~/.config/herdr/config.toml <<'EOF'
# managed by mac-setup
onboarding = false

[terminal]
new_cwd = "follow"

[update]
version_check = false
manifest_check = false

[theme]
name = "catppuccin"

[theme.custom]
accent        = "#ff5f45"
panel_bg      = "#121216"
sidebar_bg    = "#121216"
active_row_bg = "#26262e"
selection_bg  = "#5c1f1a"
surface0      = "#1a1a20"
surface1      = "#26262e"
surface_dim   = "#121216"
overlay0      = "#55555f"
overlay1      = "#8e8e9c"
text          = "#ececf1"
subtext0      = "#b0b0bd"
mauve         = "#ef9ab3"
green         = "#b5d18a"
yellow        = "#ffc27a"
red           = "#e05a6a"
blue          = "#6cc4f0"
teal          = "#8fd6c2"
peach         = "#ff5f45"

[ui]
accent = "#ff5f45"
sidebar_width = 24
sidebar_collapsed_mode = "compact"
hide_tab_bar_when_single_tab = true
pane_borders = "auto"
pane_scrollbars = false
status_indicators = "dots"
confirm_close = false
prompt_new_tab_name = false
window_title = "{workspace}"

[ui.toast]
delivery = "system"

[ui.toast.clipboard]
enabled = false

[ui.sound]
enabled = false
EOF

# Claude Code: no self-updates (env in its settings file; merges into an existing one)
mkdir -p ~/.claude
/usr/bin/python3 -I - ~/.claude/settings.json <<'PY'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) and os.path.getsize(p) else {}
d.setdefault("env", {})["DISABLE_AUTOUPDATER"] = "1"
json.dump(d, open(p, "w"), indent=2)
PY
# Transmission (Sparkle updater): no background checks
defaults write org.m0k.transmission SUEnableAutomaticChecks -bool false
defaults write org.m0k.transmission SUAutomaticallyUpdate -bool false

# AeroSpace: tiling with gaps; Alt+H/J/K/L focus, Alt+Shift+H/J/K/L move, Alt+1–5 workspaces.
# Letter workspaces and Alt-Tab are left out (Alt-B/F word jumps in the shell, AltTab owns Alt-Tab).
put ~/.config/aerospace/aerospace.toml <<'EOF'
# managed by mac-setup
config-version = 2
start-at-login = true
after-startup-command = []
enable-normalization-flatten-containers = true
enable-normalization-opposite-orientation-for-nested-containers = true
accordion-padding = 24
default-root-container-layout = 'tiles'
default-root-container-orientation = 'auto'
on-focused-monitor-changed = ['move-mouse monitor-lazy-center']
automatically-unhide-macos-hidden-apps = false
persistent-workspaces = ["1", "2", "3", "4", "5"]
key-mapping.preset = 'qwerty'
gaps.inner.horizontal = 8
gaps.inner.vertical =   8
gaps.outer.left =       8
gaps.outer.bottom =     8
gaps.outer.top =        8
gaps.outer.right =      8

[mode.main.binding]
    alt-slash = 'layout tiles horizontal vertical'
    alt-comma = 'layout accordion horizontal vertical'
    alt-shift-f = 'fullscreen'
    alt-h = 'focus left'
    alt-j = 'focus down'
    alt-k = 'focus up'
    alt-l = 'focus right'
    alt-shift-h = 'move left'
    alt-shift-j = 'move down'
    alt-shift-k = 'move up'
    alt-shift-l = 'move right'
    alt-minus = 'resize smart -50'
    alt-equal = 'resize smart +50'
    alt-1 = 'workspace 1'
    alt-2 = 'workspace 2'
    alt-3 = 'workspace 3'
    alt-4 = 'workspace 4'
    alt-5 = 'workspace 5'
    alt-shift-1 = 'move-node-to-workspace 1'
    alt-shift-2 = 'move-node-to-workspace 2'
    alt-shift-3 = 'move-node-to-workspace 3'
    alt-shift-4 = 'move-node-to-workspace 4'
    alt-shift-5 = 'move-node-to-workspace 5'
    alt-shift-semicolon = 'mode service'

[mode.service.binding]
    esc = ['reload-config', 'mode main']
    r = ['flatten-workspace-tree', 'mode main']
    f = ['layout floating tiling', 'mode main']
    backspace = ['close-all-windows-but-current', 'mode main']

# float small utility windows instead of tiling them
[[on-window-detected]]
    if.app-id = 'com.apple.systempreferences'
    run = 'layout floating'
[[on-window-detected]]
    if.app-id = 'com.apple.finder'
    run = 'layout floating'
[[on-window-detected]]
    if.app-id = 'org.localsend.localsendApp'
    run = 'layout floating'
[[on-window-detected]]
    if.app-id = 'com.objective-see.lulu.app'
    run = 'layout floating'
[[on-window-detected]]
    if.app-id = 'org.p0deje.Maccy'
    run = 'layout floating'
EOF
# btop in the dune palette
put ~/.config/btop/themes/dune.theme <<'EOF'
# managed by mac-setup
theme[main_bg]=""
theme[main_fg]="#ececf1"
theme[title]="#ececf1"
theme[hi_fg]="#ff5f45"
theme[selected_bg]="#26262e"
theme[selected_fg]="#ff8a6b"
theme[inactive_fg]="#55555f"
theme[graph_text]="#8e8e9c"
theme[meter_bg]="#26262e"
theme[proc_misc]="#6cc4f0"
theme[cpu_box]="#55555f"
theme[mem_box]="#55555f"
theme[net_box]="#55555f"
theme[proc_box]="#55555f"
theme[div_line]="#26262e"
theme[temp_start]="#6cc4f0"
theme[temp_mid]="#ffc27a"
theme[temp_end]="#ff5f45"
theme[cpu_start]="#6cc4f0"
theme[cpu_mid]="#ffc27a"
theme[cpu_end]="#ff5f45"
theme[free_start]="#55555f"
theme[free_mid]="#6cc4f0"
theme[free_end]="#8fd6c2"
theme[cached_start]="#55555f"
theme[cached_mid]="#8e8e9c"
theme[cached_end]="#b0b0bd"
theme[available_start]="#55555f"
theme[available_mid]="#8fd6c2"
theme[available_end]="#b5d18a"
theme[used_start]="#ffc27a"
theme[used_mid]="#ff8a6b"
theme[used_end]="#ff5f45"
theme[download_start]="#55555f"
theme[download_mid]="#6cc4f0"
theme[download_end]="#8fd6c2"
theme[upload_start]="#55555f"
theme[upload_mid]="#ffc27a"
theme[upload_end]="#ff5f45"
theme[process_start]="#6cc4f0"
theme[process_mid]="#ffc27a"
theme[process_end]="#ff5f45"
EOF
put ~/.config/btop/btop.conf <<'EOF'
# managed by mac-setup
color_theme = "dune"
theme_background = false
rounded_corners = false
vim_keys = true
update_ms = 1500
proc_sorting = "cpu lazy"
EOF
# lazygit in the dune palette
put ~/Library/Application\ Support/lazygit/config.yml <<'EOF'
# managed by mac-setup
gui:
  border: single
  showIcons: false
  theme:
    activeBorderColor: ['#ff5f45', bold]
    inactiveBorderColor: ['#55555f']
    selectedLineBgColor: ['#26262e']
    optionsTextColor: ['#6cc4f0']
    cherryPickedCommitFgColor: ['#ffc27a']
    unstagedChangesColor: ['#e05a6a']
    defaultFgColor: ['#ececf1']
git:
  paging:
    colorArg: always
    pager: delta --paging=never
update:
  method: never
EOF
# docker CLI ↔ Colima (open-source VM) + the compose plugin
mkdir -p ~/.docker
[[ -f ~/.docker/config.json ]] || print -r -- '{ "cliPluginsExtraDirs": ["'$BREW'/lib/docker/cli-plugins"] }' > ~/.docker/config.json
# Maccy / AltTab: quiet, no update checks
defaults write org.p0deje.Maccy SUEnableAutomaticChecks -bool false
defaults write com.lwouis.alt-tab-macos SUEnableAutomaticChecks -bool false
defaults write com.lwouis.alt-tab-macos updatePolicy -int 0
defaults write com.aone.keka SUEnableAutomaticChecks -bool false
defaults write com.aone.keka SUAutomaticallyUpdate -bool false

# ── 12. mpv ───────────────────────────────────────────────────────────────────
put ~/.config/mpv/mpv.conf <<'EOF'
# managed by mac-setup — the mpv build bundles FFmpeg: every common audio/video codec plays.
# quality: Apple-silicon hardware decode + high-quality GPU scaling, smooth motion, HDR tone-mapping
profile=high-quality
vo=gpu-next
gpu-api=auto
hwdec=auto-safe
scale=ewa_lanczossharp
cscale=ewa_lanczossharp
dscale=mitchell
deband=yes
video-sync=display-resample
interpolation=yes
tscale=oversample
target-colorspace-hint=yes
tone-mapping=bt.2446a
# audio: any channel layout, no clipping, more headroom
audio-channels=auto-safe
audio-normalize-downmix=yes
volume=100
volume-max=150
# playback
keep-open=yes
save-position-on-quit=yes
watch-later-options-remove=pause
autofit-larger=80%x80%
cache=yes
demuxer-max-bytes=512MiB
demuxer-readahead-secs=30
# streaming: paste any video URL — yt-dlp fetches it (up to 4K, best audio)
script-opts-append=ytdl_hook-ytdl_path=/opt/homebrew/bin/yt-dlp
ytdl-format=bestvideo[height<=?2160]+bestaudio/best
# subtitles + languages
sub-auto=fuzzy
sub-font="CommitMono"
sub-font-size=40
sub-border-size=2
slang=en,eng
alang=ja,jpn,en,eng
# on-screen text
osd-font="CommitMono"
osd-font-size=26
osd-color="#ECECF1"
osd-border-color="#121216"
osd-border-size=2
osd-bar-h=1.5
osd-duration=900
screenshot-directory=~/Pictures/Screenshots
screenshot-format=png
EOF
sed -i '' "s#/opt/homebrew/bin/yt-dlp#$BREW/bin/yt-dlp#" ~/.config/mpv/mpv.conf   # Intel Macs: /usr/local
put ~/.config/mpv/script-opts/osc.conf <<'EOF'
# managed by mac-setup
layout=slimbottombar
seekbarstyle=bar
hidetimeout=700
fadeduration=120
title=${filename}
EOF

# ── 13. Default apps and git ──────────────────────────────────────────────────
say "Default apps"
bundle_id() { local a=/Applications/$1.app; [[ -d $a ]] && defaults read "$a/Contents/Info" CFBundleIdentifier 2>/dev/null; }
set_default() { local n=$1 id=$(bundle_id "$1"); shift; [[ -z $id ]] && { warn "$n not found for defaults"; return; }
           for e in "$@"; do duti -s "$id" "$e" all; done; }
set_default mpv                    mp4 mkv mov avi webm m4v flv wmv mp3 flac wav m4a ogg opus aac
set_default Ghostty                command tool
set_default Transmission           torrent
TRANSMISSION_ID=$(bundle_id Transmission); [[ -n $TRANSMISSION_ID ]] && duti -s "$TRANSMISSION_ID" magnet
if command -v git >/dev/null; then
  git_set() { git config --global "$@"; }
  git_set core.editor nvim; git_set init.defaultBranch main; git_set pull.rebase true; git_set push.autoSetupRemote true
  git_set fetch.prune true; git_set rerere.enabled true; git_set diff.algorithm histogram; git_set merge.conflictstyle zdiff3
  git_set core.pager delta; git_set interactive.diffFilter "delta --color-only"; git_set delta.navigate true; git_set delta.line-numbers true
  git_set delta.syntax-theme ansi; git_set delta.minus-style "syntax #3a1820"; git_set delta.plus-style "syntax #1c2a1a"
  git_set delta.line-numbers-minus-style "#e05a6a"; git_set delta.line-numbers-plus-style "#b5d18a"; git_set delta.hunk-header-style "#ffc27a"
  git_set color.ui auto; git_set color.diff.new "#b5d18a"; git_set color.diff.old "#e05a6a"
  git_set color.diff.meta "#8e8e9c"; git_set color.diff.frag "#ffc27a"; git_set color.status.branch "#ff5f45"
fi
defaultbrowser firefox   # macOS asks once → "Use Firefox"

# ── 14. Firefox: policies, extensions, theme ──────────────────────────────────
# Stored as a system policy plist: Firefox applies it every launch, survives app updates and profile resets.
say "Firefox policies"
FF_POLICY=$(mktemp -d)/policies.json
cat > $FF_POLICY <<'JSON'
{ "policies": {
  "ExtensionSettings": {
    "uBlock0@raymondhill.net": { "installation_mode": "force_installed", "default_area": "menupanel",
      "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" },
    "78272b6fa58f4a1abaac99321d503a20@proton.me": { "installation_mode": "force_installed", "default_area": "menupanel",
      "install_url": "https://addons.mozilla.org/firefox/downloads/latest/proton-pass/latest.xpi" }
  },
  "EncryptedMediaExtensions": { "Enabled": true, "Locked": false },
  "DisplayBookmarksToolbar": "never",
  "AppAutoUpdate": false,
  "BackgroundAppUpdate": false,
  "ExtensionUpdate": false,
  "NewTabPage": false,
  "Homepage": { "URL": "about:blank", "StartPage": "homepage", "Locked": false },
  "DisableTelemetry": true,
  "DisableFirefoxStudies": true,
  "DisablePocket": true,
  "DisableFeedbackCommands": true,
  "DisableSetDesktopBackground": true,
  "DontCheckDefaultBrowser": true,
  "OfferToSaveLogins": false,
  "PasswordManagerEnabled": false,
  "NoDefaultBookmarks": true,
  "OverrideFirstRunPage": "",
  "OverridePostUpdatePage": "",
  "UserMessaging": { "WhatsNew": false, "ExtensionRecommendations": false, "FeatureRecommendations": false,
                     "UrlbarInterventions": false, "SkipOnboarding": true, "MoreFromMozilla": false, "Locked": false },
  "FirefoxHome": { "Search": true, "TopSites": false, "SponsoredTopSites": false, "Highlights": false,
                   "Pocket": false, "SponsoredPocket": false, "Snippets": false, "Locked": false },
  "FirefoxSuggest": { "WebSuggestions": false, "SponsoredSuggestions": false, "ImproveSuggest": false, "Locked": false },
  "EnableTrackingProtection": { "Value": true, "Cryptomining": true, "Fingerprinting": true, "EmailTracking": true },
  "HttpsOnlyMode": "enabled",
  "Preferences": {
    "sidebar.verticalTabs":             { "Value": false, "Status": "default" },
    "browser.compactmode.show":         { "Value": true,  "Status": "default" },
    "browser.uidensity":                { "Value": 1,     "Status": "default" },
    "browser.tabs.firefox-view":        { "Value": false, "Status": "default" },
    "browser.tabs.tabmanager.enabled":  { "Value": false, "Status": "default" },
    "browser.toolbars.bookmarks.visibility": { "Value": "never", "Status": "default" },
    "browser.download.autohideButton":  { "Value": true,  "Status": "default" },
    "extensions.unifiedExtensions.button.always_visible": { "Value": true,  "Status": "default" },
    "browser.tabs.inTitlebar":          { "Value": 1,     "Status": "default" },
    "browser.theme.toolbar-theme":      { "Value": 0,     "Status": "default" },
    "browser.theme.content-theme":      { "Value": 0,     "Status": "default" },
    "layout.css.prefers-color-scheme.content-override": { "Value": 0, "Status": "default" },
    "browser.aboutConfig.showWarning":  { "Value": false, "Status": "default" },
    "browser.ml.chat.enabled":          { "Value": false, "Status": "default" },
    "browser.newtabpage.activity-stream.showSponsored": { "Value": false, "Status": "default" },
    "browser.urlbar.trimHttps":         { "Value": true,  "Status": "default" },
    "media.eme.enabled":                { "Value": true,  "Status": "default" },
    "media.gmp-widevinecdm.enabled":    { "Value": true,  "Status": "default" },
    "gfx.webrender.all":                { "Value": true,  "Status": "default" }
  }
} }
JSON
plutil -extract policies json -o - $FF_POLICY | plutil -convert xml1 -o $FF_POLICY.plist - \
  && plutil -insert EnterprisePoliciesEnabled -bool true $FF_POLICY.plist \
  && sudo cp $FF_POLICY.plist /Library/Preferences/org.mozilla.firefox.plist \
  && sudo chmod 644 /Library/Preferences/org.mozilla.firefox.plist \
  || warn "Firefox policies not written"
rm -f $FF_POLICY $FF_POLICY.plist

FF_PENDING=0
ff_theme() {   # user.js + userChrome/userContent into the profile Firefox actually uses
  local profile=$(ff_profile); [[ -n $profile ]] || return 1
  put "$profile/user.js" <<'EOF'
// managed by mac-setup
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
user_pref("browser.display.background_color.dark", "#121216");
user_pref("browser.uidensity", 1);
user_pref("browser.tabs.tabMinWidth", 120);
user_pref("ui.prefersReducedMotion", 1);
user_pref("general.smoothScroll", false);
user_pref("browser.sessionstore.interval", 60000);          // session saves every 60s, not 15s
user_pref("browser.startup.preXulSkeletonUI", false);
// speed: no local AI models, no accessibility engine, no background extras
user_pref("browser.ml.enable", false);
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("accessibility.force_disabled", 1);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.translations.automaticallyPopup", false);
user_pref("media.videocontrols.picture-in-picture.video-toggle.enabled", false);
user_pref("browser.shopping.experience2023.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
// quieter address bar
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.recentsearches", false);
user_pref("browser.urlbar.trending.featureGate", false);
user_pref("browser.urlbar.shortcuts.bookmarks", false);
user_pref("browser.urlbar.shortcuts.tabs", false);
user_pref("browser.urlbar.shortcuts.history", false);
EOF
  put "$profile/chrome/userChrome.css" <<'EOF'
/* managed by mac-setup — dune */
:root {
  --e-bg:#121216; --e-s1:#1a1a20; --e-s2:#26262e; --e-line:#55555f;
  --e-fg:#ececf1; --e-dim:#b0b0bd; --e-acc:#ff5f45; --e-peach:#ffc27a;
  --lwt-accent-color: var(--e-bg) !important;  --lwt-text-color: var(--e-fg) !important;
  --toolbar-bgcolor: var(--e-s1) !important;   --toolbar-color: var(--e-fg) !important;
  --tab-selected-bgcolor: var(--e-s2) !important; --tab-selected-textcolor: var(--e-fg) !important;
  --toolbar-field-background-color: var(--e-bg) !important;
  --toolbar-field-focus-background-color: var(--e-bg) !important;
  --toolbar-field-color: var(--e-fg) !important; --toolbar-field-focus-color: var(--e-fg) !important;
  --toolbar-field-focus-border-color: var(--e-acc) !important;
  --focus-outline-color: var(--e-acc) !important;
  --arrowpanel-background: var(--e-s1) !important; --arrowpanel-color: var(--e-fg) !important;
  --arrowpanel-border-color: var(--e-line) !important;
  --chrome-content-separator-color: var(--e-line) !important;
  --urlbarView-highlight-background: var(--e-acc) !important; --urlbarView-highlight-color: var(--e-bg) !important;
  --tab-loading-fill: var(--e-acc) !important; --button-primary-bgcolor: var(--e-acc) !important;
  --tab-border-radius: 4px !important; --toolbarbutton-border-radius: 4px !important;
}
#navigator-toolbox { background: var(--e-bg) !important; border-bottom: 1px solid var(--e-line) !important; }
.tab-background:is([selected], [multiselected]) { box-shadow: inset 0 -2px 0 var(--e-acc) !important; }
.tab-label { font-size: 12px !important; }
#urlbar-background { border-radius: 4px !important; border: 1px solid var(--e-line) !important; }
#urlbar[focused] #urlbar-background { border-color: var(--e-acc) !important; }
#firefox-view-button, #alltabs-button, .titlebar-spacer { display: none !important; }
/* toolbar: back · reload · address bar · puzzle (extensions) · ≡ */
#forward-button:is([disabled]), #fxa-toolbar-menu-button,
#sidebar-button, #save-to-pocket-button, #home-button, #library-button,
#tracking-protection-icon-container, #identity-permission-box, #star-button-box,
#reader-mode-button, #translations-button, #picture-in-picture-button,
#pageActionButton, #urlbar-zoom-button, #tabs-newtab-button .toolbarbutton-text,
#PanelUI-menu-button .toolbarbutton-badge-stack .toolbarbutton-badge { display: none !important; }
#identity-box { margin-inline-end: 4px !important; }
.tabbrowser-tab:not([selected]):not(:hover) .tab-close-button { display: none !important; }
#nav-bar { padding-block: 2px !important; }
::selection { background: #5c1f1a !important; color: #fff1e6 !important; }
EOF
  put "$profile/chrome/userContent.css" <<'EOF'
/* managed by mac-setup — dark blank pages, no white flash */
@-moz-document url("about:blank"), url("about:newtab"), url("about:home"), url("about:privatebrowsing") {
  html, body { background: #121216 !important; color: #ececf1 !important; }
}
EOF
}
# Firefox look: same palette as the terminal. Firefox only creates its profile on first
# launch, so start it once headless (no window), then drop in user.js + userChrome.css.
if [[ -x $FF_BIN ]]; then
  xattr -dr com.apple.quarantine /Applications/Firefox.app 2>/dev/null   # Homebrew already verified its checksum
  if [[ -z $(ff_profile) ]]; then
    "$FF_BIN" --headless --screenshot "$(mktemp -d)/x.png" about:blank >/dev/null 2>&1 &
    FF_PID=$!; for _ in {1..90}; do kill -0 $FF_PID 2>/dev/null || break; sleep 1; done   # ~40s, exits itself
    kill $FF_PID 2>/dev/null; wait $FF_PID 2>/dev/null
  fi
  ff_theme || FF_PENDING=1        # no profile yet: themed once Firefox opens at the end
fi
open -a LuLu
sleep 3; open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" 2>/dev/null   # switch LuLu on here

# ── 15. Apply and clean up ────────────────────────────────────────────────────
killall cfprefsd Dock Finder SystemUIServer ControlCenter 2>/dev/null
brew cleanup --prune=all -s >/dev/null 2>&1                            # drop every cached installer
rm -rf "${HOME:?}/Library/Caches/Homebrew" "${HOME:?}"/Library/Caches/com.apple.Safari* 2>/dev/null
sudo rm -rf /Library/Updates/* /private/var/folders/*/*/C/com.apple.appstore* 2>/dev/null
[[ -f $KIT/quickstart.html ]] && cp -f $KIT/quickstart.html ~/quickstart.html && open -a Firefox ~/quickstart.html   # your cheat sheet
if (( FF_PENDING )); then
  for _ in {1..45}; do [[ -n $(ff_profile) ]] && break; sleep 2; done
  ff_theme || warn "Firefox theme not applied — open Firefox once, then re-run the script"
fi
# ── 16. Verify and finish ─────────────────────────────────────────────────────
run_checks
say "Finished in $((SECONDS/60))m $((SECONDS%60))s."
say "Done → REBOOT (services + Game Mode take effect). Then the clicks macOS won't let a script do:"
print "  • LuLu: switch it on in the settings page that opened"
print "  • Click “Use Firefox” in the default-browser dialog"
print "  • Proton Pass: sign in (Firefox › puzzle-piece button)"
print "  • AeroSpace, AltTab, Maccy: click Allow for Accessibility when each first opens"
print "  • Cheat sheet: ~/quickstart.html (open in Firefox now)"
print "  • Finder sidebar: drag out what you don't use (macOS no longer lets scripts edit it)"
print "  • After the reboot, confirm everything:  zsh ${(D)KIT}/mac-setup.sh --check"
command -v claude >/dev/null && [[ ! -f ~/.claude.json ]] && open -na Ghostty --args -e claude   # log in to Claude Code
for a in AeroSpace AltTab Maccy; do [[ -d /Applications/$a.app ]] && open -a $a; done
(( ${#FAILS} )) && { print -P "%F{214}Needs attention:%f"; printf '  - %s\n' "${FAILS[@]}"; } \
               || print -P "%F{114}Everything checked out.%f"
if [[ -t 0 ]] && read -q "?Reboot now? [y/N] "; then print; sudo shutdown -r now; fi; print

#!/usr/bin/env bash
# Open Cairn (notes.cjnowacek.com) from the launcher (cairn.desktop).
#
# Firefox first (below). With CAIRN_BROWSER=chrome: the installed Chrome app when it is there: the same window the page's
# "pop out" button opens. Chrome drops an installed app without a word
# (gone by 2026-10-22, three days after it was installed), and --app-id for
# an app it no longer has opens an empty New Tab window instead, so check
# for its manifest folder first and fall back to a plain app window on the
# same address. Both window classes match the cairn-web rule in hyprland.lua.
# Reinstalling from the page gives the same app id (Chrome derives it from
# the page's manifest), so nothing here changes when it comes back.
PROFILE="Profile 1"
APP_ID=ekamnaoljcinngmggjdmagnkcmgnfckp
URL=https://notes.cjnowacek.com

# Chrome writes a desktop entry of its own for the installed app, also
# called Cairn, and wofi lists both (2026-10-29: "two?"). This entry is the
# one to keep, since it survives Chrome dropping the app; Chrome rewrites
# its file whenever it refreshes the app, so it is hidden again here on
# every launch rather than once.
CHROME_ENTRY="$HOME/.local/share/applications/chrome-$APP_ID-${PROFILE// /_}.desktop"
if [ -f "$CHROME_ENTRY" ] && ! grep -q '^NoDisplay=true' "$CHROME_ENTRY"; then
  sed -i '/^NoDisplay=/d; /^\[Desktop Entry\]/a NoDisplay=true' "$CHROME_ENTRY"
fi
# In Firefox since 2026-10-30 (the user: "have the super d cairn run with
# firefox", then "should be the pop out version", "i don't like chrome"):
# a Firefox profile of Cairn's own, with no tab strip or toolbar
# (cairn-firefox/userChrome.css), so it opens as one bare window the way the
# page's pop out does. Made on first launch; its settings are linked from
# here so they stay in the dotfiles. Its window class is cairn-web, for a
# window rule to match. Proton Pass and Claudezilla are not in
# it; Cairn asks for its password once. CAIRN_BROWSER=chrome brings back the
# installed Chrome app below.
if [ "${CAIRN_BROWSER:-firefox}" = firefox ] && command -v firefox >/dev/null; then
  HERE="$(dirname "$(readlink -f "$0")")"
  FFROOT="$HOME/.config/mozilla/firefox"
  PROF="$FFROOT/cairn"
  if ! grep -q '^Name=cairn$' "$FFROOT/profiles.ini" 2>/dev/null; then
    firefox --headless -CreateProfile "cairn $PROF" >/dev/null 2>&1
  fi
  mkdir -p "$PROF/chrome"
  ln -sf "$HERE/cairn-firefox/user.js" "$PROF/user.js"
  ln -sf "$HERE/cairn-firefox/userChrome.css" "$PROF/chrome/userChrome.css"
  exec firefox -P cairn --name cairn-web --class cairn-web --new-window "$URL"
fi
if [ -d "$HOME/.config/google-chrome/$PROFILE/Web Applications/Manifest Resources/$APP_ID" ]; then
  exec google-chrome-stable "--profile-directory=$PROFILE" "--app-id=$APP_ID"
fi
exec google-chrome-stable "--profile-directory=$PROFILE" "--app=$URL"

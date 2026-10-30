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
# firefox"): a new window of the running Firefox, so Proton Pass and
# Claudezilla are there as in any tab. Firefox has no app-window mode, so
# this is an ordinary window. CAIRN_BROWSER=chrome brings back the
# installed Chrome app below.
if [ "${CAIRN_BROWSER:-firefox}" = firefox ] && command -v firefox >/dev/null; then
  exec firefox --new-window "$URL"
fi
if [ -d "$HOME/.config/google-chrome/$PROFILE/Web Applications/Manifest Resources/$APP_ID" ]; then
  exec google-chrome-stable "--profile-directory=$PROFILE" "--app-id=$APP_ID"
fi
exec google-chrome-stable "--profile-directory=$PROFILE" "--app=$URL"

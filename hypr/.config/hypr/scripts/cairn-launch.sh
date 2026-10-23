#!/usr/bin/env bash
# Open Cairn (notes.cjnowacek.com) from the launcher (cairn.desktop).
#
# The installed Chrome app when it is there: the same window the page's
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
if [ -d "$HOME/.config/google-chrome/$PROFILE/Web Applications/Manifest Resources/$APP_ID" ]; then
  exec google-chrome-stable "--profile-directory=$PROFILE" "--app-id=$APP_ID"
fi
exec google-chrome-stable "--profile-directory=$PROFILE" "--app=$URL"

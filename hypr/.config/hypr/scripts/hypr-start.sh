#!/usr/bin/env bash
# exec-once wrapper. Under a uwsm-managed session (the desktop), launch the
# app as its own systemd unit: `journalctl --user -u app-<name>*` gets its
# logs, and a crash stays out of the compositor's cgroup. Elsewhere (the
# laptop, no uwsm) it degrades to a plain exec.
if command -v uwsm >/dev/null && uwsm check is-active >/dev/null 2>&1; then
  exec uwsm app -- "$@"
fi
exec "$@"

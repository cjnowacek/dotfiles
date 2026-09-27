# Machine notes (Windows 11 Home, hostname DESKTOP-QE7H7TN)

Repos live in `C:\dev`; the dotfiles clone is `C:\dev\dotfiles` and
`bootstrap.ps1 -Links` refreshes every link below without installing anything.
To give this computer a better name: `echo <name> > ~/.config/dotfiles/machine`,
rename `claude/.claude/machines/desktop-qe7h7tn/`, run `bootstrap.ps1 -Links`.

## Git Bash on this box: symlinks, python, paths

- `ln -s` in Git Bash makes a COPY unless `MSYS=winsymlinks:nativestrict` is
  set; Developer Mode is on, so native symlinks then work without admin.
  `bootstrap.ps1` uses junctions for directories and symlinks for files.
- `python3` is the Microsoft Store alias (3.11). It is a native Windows
  program: it cannot open MSYS paths like `/tmp/x` or `/c/dev/x`. Give it
  `C:/dev/x` (`cygpath -m`) when a path crosses from bash into python.
- Backslashes in a command string handed to the Bash tool arrive halved
  (`\\` becomes `\`), so JSON with Windows paths written inline is malformed.
  Use forward slashes in test input; real hook input comes on stdin, unaffected.

## Subagents: triage every request, dispatch without asking

The rule for which work the main session keeps and which it sends to a
subagent is `~/dev/subagent-workflow-kit/templates/ROUTING.md` (on this
machine `~/dev/subagent-workflow-kit` is a junction to
`C:\dev\subagent-workflow-kit`); a repo may carry its own `.claude/ROUTING.md`,
which wins. Short version: questions, design, anything with a silent failure
mode, the check, the gate, the look and every commit stay with the main
session; a pinned-down change with a check goes to `implementer` (in
`~/.claude/agents`, linked from the kit), a sweep across files to `Explore`.
Say in one line what was sent and to whom; never wait for a veto. The user,
2026-09-24: "as you see fit for the type of task it is. and then ill just
staying in fable."

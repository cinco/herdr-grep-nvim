#!/usr/bin/env bash
# grep-nvim — the "open" action.
#
# Splits the focused pane to the right and runs the fzf + ripgrep live-grep picker
# there (scripts/fzf-grep-nvim.sh). Enter opens the selected match in nvim at the
# line; the pane closes itself when you quit nvim (or press Esc in fzf).
#
# Invoked as `grep-nvim.open` (see ../herdr-plugin.toml). herdr runs plugin
# commands with the plugin dir as cwd and a MINIMAL PATH, so we (a) enrich PATH to
# find the herdr CLI + jq, and (b) never rely on the process cwd — we take the
# repo dir from the herdr-provided context instead.
set -uo pipefail

# herdr runs plugin commands with a minimal PATH; ensure herdr + jq resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME:-}/.local/bin:/usr/bin:/bin:${PATH:-}"

H="${HERDR_BIN_PATH:-herdr}"
DIRECTION="${GREP_NVIM_DIRECTION:-right}"   # right | down

command -v jq >/dev/null 2>&1 || { printf 'grep-nvim: jq not found on PATH\n' >&2; exit 127; }

# Where to grep: the focused pane's shell cwd (the repo you are working in).
cwd=""
if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
  cwd=$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.focused_pane_cwd // .workspace_cwd // empty' 2>/dev/null)
fi
# Fallback: ask herdr for the focused pane directly.
if [ -z "$cwd" ]; then
  cwd=$("$H" pane current --current 2>/dev/null | jq -r '.result.pane.cwd // empty' 2>/dev/null)
fi
[ -n "$cwd" ] || { printf 'grep-nvim: no workspace context (run this from inside herdr)\n' >&2; exit 1; }

# Split the focused pane. A bare split inherits the foreground process cwd, so we
# pass --cwd explicitly. We also seed the new pane with the picker's path as an env
# var ($GREP_NVIM_SCRIPT), so the command we type into it references the variable
# rather than echoing the absolute path (which would briefly flash your home path in
# the pane before fzf takes over). Prefer the injected pane id; fall back to --current.
script="$HERDR_PLUGIN_ROOT/scripts/fzf-grep-nvim.sh"
target="${HERDR_PANE_ID:-}"
if [ -n "$target" ]; then
  split_json=$("$H" pane split "$target" --direction "$DIRECTION" --cwd "$cwd" --env "GREP_NVIM_SCRIPT=$script" --focus 2>/dev/null)
else
  split_json=$("$H" pane split --current --direction "$DIRECTION" --cwd "$cwd" --env "GREP_NVIM_SCRIPT=$script" --focus 2>/dev/null)
fi
pane=$(printf '%s' "$split_json" | jq -r '.result.pane.pane_id // empty' 2>/dev/null)
[ -n "$pane" ] || { printf 'grep-nvim: failed to open the split pane\n' >&2; exit 1; }

# Run the picker in the new pane. `exec` replaces the pane shell, so the pane closes
# by itself when the picker/editor exits. Referencing $GREP_NVIM_SCRIPT (not the
# literal path) keeps the transient command line free of your home path.
sleep 0.5   # let the new shell initialize before we send it a command
"$H" pane run "$pane" 'exec bash "$GREP_NVIM_SCRIPT"'

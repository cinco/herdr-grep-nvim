#!/usr/bin/env bash
# grep-nvim — live-grep the repo with fzf + ripgrep; Enter opens the match in nvim
# at the line. Runs inside the herdr split pane opened by scripts/open.sh.
#
# How it works:
#   - fzf runs with --disabled, so it does NO filtering itself; ripgrep does the
#     searching, re-run on each keystroke via the `change:reload` bind (debounced
#     with a tiny sleep). An empty query searches nothing.
#   - rg --column output is `path:line:col:text`. On Enter, fzf prints the selected
#     line; we recover the path and line in the shell (robust to colons in the path)
#     and exec the editor. On Esc / no match, nothing opens.
#   - The editor replaces this script's process, so when you quit it the pane's
#     process exits and the herdr split closes itself.
#
# Env overrides (optional):
#   GREP_NVIM_EDITOR   editor command (default: nvim; must accept `+LINE -- file`,
#                      may include args, e.g. "nvim -u NONE")
#   GREP_NVIM_RG_FLAGS extra ripgrep flags, e.g. "--hidden -g !.git" or "-t py"
set -uo pipefail

# Be robust even under a reduced PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME:-}/.local/bin:/usr/bin:/bin:${PATH:-}"

EDITOR_CMD="${GREP_NVIM_EDITOR:-nvim}"
editor_bin=${EDITOR_CMD%% *}   # GREP_NVIM_EDITOR is word-split (like $EDITOR); preflight its first word

# Preflight: fail with a clear, visible message if a required tool is missing.
missing=()
for dep in fzf rg "$editor_bin"; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [ "${#missing[@]}" -gt 0 ]; then
  printf '\n  grep-nvim: missing required tool(s): %s\n' "${missing[*]}" >&2
  printf '  Needs: fzf, ripgrep (rg), %s.  bat is optional (nicer preview).\n\n' "$editor_bin" >&2
  sleep 4
  exit 127
fi

RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case ${GREP_NVIM_RG_FLAGS:-}"
# Shared reload body: ripgrep only runs for a non-empty query.
reload_cmd="[ -n {q} ] && $RG_PREFIX -- {q} || true"

# Preview: bat (line highlight) if present, else plain cat. fzf's `+{2}` preview
# offset scrolls the preview to the matched line in both cases.
if command -v bat >/dev/null 2>&1; then
  PREVIEW='bat --style=numbers --color=always --highlight-line {2} -- {1}'
else
  PREVIEW='cat -- {1}'
fi

# On Enter fzf prints the selected `path:line:col:text`; Esc / no match prints nothing.
sel=$(
  fzf --ansi --disabled \
      --height '100%' \
      --prompt 'grep> ' \
      --info inline \
      --bind "start:reload:$reload_cmd" \
      --bind "change:reload:sleep 0.1; $reload_cmd" \
      --delimiter ':' \
      --preview "$PREVIEW" \
      --preview-window 'right,60%,border-left,+{2}+3/3,~3'
)
[ -n "$sel" ] || exit 0

# rg --column output is `path:line:col:text`. Recover the path with a colon-robust
# strip of the trailing :line:col:text, then take the line as the first field right
# after that path — so a match whose TEXT contains a :num:num: run cannot hijack the
# line number, and path and line always derive from the same boundary.
file=$(printf '%s' "$sel" | sed -E 's/:[0-9]+:[0-9]+:.*$//')
rest=${sel#"$file":}
line=${rest%%:*}

# `--` guards a filename beginning with '-'; $EDITOR_CMD is left unquoted so a
# multi-word GREP_NVIM_EDITOR (e.g. "nvim -u NONE") splits into words.
case $line in
  ''|*[!0-9]*) exec $EDITOR_CMD -- "$file" ;;
  *)           exec $EDITOR_CMD +"$line" -- "$file" ;;
esac

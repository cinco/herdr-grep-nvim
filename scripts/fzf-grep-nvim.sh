#!/usr/bin/env bash
# grep-nvim — live-grep the repo with fzf + ripgrep; Enter opens the match in nvim
# at the line. Runs inside the herdr split pane opened by scripts/open.sh.
#
# How it works:
#   - fzf runs with --disabled, so it does NO filtering itself; ripgrep does the
#     searching, re-run on each keystroke via the `change:reload` bind (debounced
#     with a tiny sleep). An empty query searches nothing.
#   - rg --column output is `path:line:col:text`; with --delimiter ':' that makes
#     fzf field {1}=path and {2}=line.
#   - `become(nvim {1} +{2})` replaces fzf with nvim on Enter, opening the file at
#     the matched line. On Esc, fzf just exits. Either way open.sh appended `; exit`,
#     so the pane closes when you are done.
#
# Env overrides (optional):
#   GREP_NVIM_EDITOR   editor command (default: nvim; must accept `+LINE file`)
#   GREP_NVIM_RG_FLAGS extra ripgrep flags, e.g. "--hidden -g !.git" or "-t py"
set -uo pipefail

# Be robust even under a reduced PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME:-}/.local/bin:/usr/bin:/bin:${PATH:-}"

EDITOR_CMD="${GREP_NVIM_EDITOR:-nvim}"

# Preflight: fail with a clear, visible message if a required tool is missing.
missing=()
for dep in fzf rg "$EDITOR_CMD"; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [ "${#missing[@]}" -gt 0 ]; then
  printf '\n  grep-nvim: missing required tool(s): %s\n' "${missing[*]}" >&2
  printf '  Needs: fzf, ripgrep (rg), %s.  bat is optional (nicer preview).\n\n' "$EDITOR_CMD" >&2
  sleep 4
  exit 127
fi

RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case ${GREP_NVIM_RG_FLAGS:-}"

# Preview: bat (line highlight) if present, else plain cat. fzf's `+{2}` preview
# offset scrolls the preview to the matched line in both cases.
if command -v bat >/dev/null 2>&1; then
  PREVIEW='bat --style=numbers --color=always --highlight-line {2} -- {1}'
else
  PREVIEW='cat -- {1}'
fi

fzf --ansi --disabled \
    --height '100%' \
    --prompt 'grep> ' \
    --info inline \
    --bind "start:reload:[ -n {q} ] && $RG_PREFIX -- {q} || true" \
    --bind "change:reload:sleep 0.1; [ -n {q} ] && $RG_PREFIX -- {q} || true" \
    --delimiter ':' \
    --preview "$PREVIEW" \
    --preview-window 'right,60%,border-left,+{2}+3/3,~3' \
    --bind "enter:become($EDITOR_CMD {1} +{2})"

# grep-nvim demo — regenerate with:  vhs assets/demo.tape   (run from the repo root)
# Records in an isolated herdr session ("grepdemo") so it never touches your live one.
# Assumes prefix+alt+f is bound to grep-nvim.open in your herdr config (see README > Install).
Output "assets/demo.gif"
Set Shell "bash"
Set FontSize 16
Set Width 1280
Set Height 720
Set Padding 18

# --- setup (hidden): open an isolated herdr session at the repo and link the plugin ---
Hide
Type "export PS1='$ '; clear" Enter
Type "herdr session attach grepdemo" Enter
Sleep 4s
Type 'herdr plugin link "$PWD" >/dev/null 2>&1; clear' Enter
Sleep 2s
Show

# --- the demo: press the key, the grep pane splits in beside you ---
Sleep 1500ms
Ctrl+B
Sleep 150ms
Alt+f
Sleep 3800ms
Type@180ms "split"
Sleep 2800ms
Enter
Sleep 4000ms

#!/usr/bin/env bash
# Installs sspinner: symlinks the CLI onto $PATH and checks for its runtime deps.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

chmod +x "$REPO_DIR/sspinner"
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/sspinner" "$BIN_DIR/sspinner"
echo "sspinner -> $BIN_DIR/sspinner (symlinked from $REPO_DIR)"

# One-time cleanup from the tool's pre-rename life as 'devstack': drop the
# stale symlink (it points at a file that no longer exists in this repo) and
# strip the old completion blocks from the shell rc files. The registry and
# Dozzle container migrate themselves on first run - see load_registry() and
# infra_up() in the sspinner script.
if [ -L "$BIN_DIR/devstack" ] && [ ! -e "$BIN_DIR/devstack" ]; then
  rm "$BIN_DIR/devstack"
  echo "removed stale devstack symlink from $BIN_DIR"
fi
if [ -f "$HOME/.bashrc" ] && grep -qF "# devstack completion" "$HOME/.bashrc"; then
  sed -i '/^# devstack completion$/,+1d' "$HOME/.bashrc"
  echo "removed old devstack completion block from ~/.bashrc"
fi
if [ -f "$HOME/.zshrc" ] && grep -qF "# devstack completion" "$HOME/.zshrc"; then
  sed -i '/^# devstack completion$/,+2d' "$HOME/.zshrc"
  echo "removed old devstack completion block from ~/.zshrc"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*)
    ;;
  *)
    echo
    echo "warning: $BIN_DIR is not on your \$PATH."
    echo "Add this to your shell rc (~/.bashrc, ~/.zshrc, ...):"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo
echo "Shell completion:"

MARKER="# sspinner completion"

if [ -f "$HOME/.bashrc" ]; then
  if ! grep -qF "$MARKER" "$HOME/.bashrc"; then
    {
      echo ""
      echo "$MARKER"
      echo "[ -f \"$REPO_DIR/completions/sspinner.bash\" ] && source \"$REPO_DIR/completions/sspinner.bash\""
    } >> "$HOME/.bashrc"
    echo "  added to ~/.bashrc (open a new shell, or: source ~/.bashrc)"
  else
    echo "  already present in ~/.bashrc"
  fi
fi

if [ -f "$HOME/.zshrc" ]; then
  if ! grep -qF "$MARKER" "$HOME/.zshrc"; then
    {
      echo ""
      echo "$MARKER"
      echo "fpath=(\"$REPO_DIR/completions\" \$fpath)"
      echo "autoload -U compinit && compinit"
    } >> "$HOME/.zshrc"
    echo "  added to ~/.zshrc (open a new shell, or: source ~/.zshrc)"
  else
    echo "  already present in ~/.zshrc"
  fi
fi

echo
echo "Checking dependencies:"

if command -v docker >/dev/null 2>&1; then
  echo "  [x] docker found"
else
  echo "  [ ] docker not found - sspinner needs it for docker-compose services and the Dozzle log viewer"
fi

if command -v terminator >/dev/null 2>&1; then
  echo "  [x] terminator found (preferred for 'sspinner run' - real split panes in its own window)"
else
  # Mirrors resolve_terminal()'s priority in the sspinner script itself:
  # $TERMINAL, then the system default (x-terminal-emulator), then a probe
  # list of common emulators.
  detected_terminal=""
  if [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
    detected_terminal="$TERMINAL"
  elif command -v x-terminal-emulator >/dev/null 2>&1; then
    detected_terminal="x-terminal-emulator"
  else
    for candidate in gnome-terminal konsole xfce4-terminal kitty alacritty wezterm xterm; do
      if command -v "$candidate" >/dev/null 2>&1; then
        detected_terminal="$candidate"
        break
      fi
    done
  fi
  if [ -n "$detected_terminal" ]; then
    echo "  [x] $detected_terminal found ('sspinner run' will open one window per service - install terminator for a nicer single-window grid)"
  else
    echo "  [ ] no terminal emulator found - 'sspinner run' will fall back to sequential mode (no split panes)"
    echo "      recommended: sudo apt install terminator"
  fi
fi

echo
echo "Try: sspinner --help"
echo "Then: sspinner register <project>"

#!/bin/bash
set -euo pipefail
sleep 1
clear
echo "############################################################################"
echo "#                          Python Installer                                 #"
echo "#               by Nico L and Kyle Smith (mrsmith9)                        #"
echo "#                   https://github.com/ipexadev/scripts                    #"
echo "#                          Last Update: 2026-06-28                         #"
echo "############################################################################"
sleep 1

if (( EUID != 0 )); then
  echo "############################################################################"
  echo "#                            Please run as root                            #"
  echo "############################################################################"
  exit 1
fi

echo "############################################################################"
echo "#                      Installing prerequisites (apt)                      #"
echo "############################################################################"
apt update -y
apt upgrade -y
apt install -y --no-install-recommends \
  make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev llvm libncursesw5-dev xz-utils tk-dev libxml2-dev \
  libxmlsec1-dev libffi-dev liblzma-dev curl git ca-certificates

PYENV_ROOT="/opt/pyenv"
if [ ! -d "$PYENV_ROOT" ]; then
  echo "Creating pyenv root at $PYENV_ROOT"
  mkdir -p "$PYENV_ROOT"
  git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
else
  echo "pyenv already present at $PYENV_ROOT — updating"
  (cd "$PYENV_ROOT" && git pull --ff-only)
fi

export PYENV_ROOT="$PYENV_ROOT"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(/opt/pyenv/bin/pyenv init -)" || true

echo "############################################################################"
echo "#                      Determining latest stable Python                     #"
echo "############################################################################"
# Use pyenv to list installable versions and pick the last stable 3.x.y
latest_version=$(/opt/pyenv/bin/pyenv install --list 2>/dev/null | \
  grep -E '^\s*3\.[0-9]+\.[0-9]+$' | sed 's/^[[:space:]]*//' | tail -1 || true)

if [ -z "$latest_version" ]; then
  echo "Could not determine latest Python version via pyenv; exiting"
  exit 1
fi

echo "Latest Python version detected: $latest_version"

echo "############################################################################"
echo "#                          Installing Python $latest_version                #"
echo "############################################################################"
/opt/pyenv/bin/pyenv install -s "$latest_version"
/opt/pyenv/bin/pyenv global "$latest_version"

echo "############################################################################"
echo "#                    Persisting pyenv to /etc/profile.d                    #"
echo "############################################################################"
cat > /etc/profile.d/pyenv.sh <<'EOF'
export PYENV_ROOT=/opt/pyenv
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(/opt/pyenv/bin/pyenv init -)"
EOF
chmod 644 /etc/profile.d/pyenv.sh

echo "############################################################################"
echo "#                        Installed Python successfully                     #"
echo "############################################################################"
echo "Python version: $(/opt/pyenv/bin/pyenv versions --bare | head -n1)"
echo "To use pyenv in an interactive shell, open a new session or source /etc/profile.d/pyenv.sh"
echo "###########################################################################"

exit 0

# Select a file with fzf and preview it with bat.
ff() {
  fzf --preview 'bat --style=numbers --color=always {}' "$@"
}

eff() {
  local file
  file="$(ff "$@")" || return
  [[ -n "${file}" ]] || return
  "${EDITOR}" "${file}"
}

sff() {
  if (( $# == 0 )); then
    echo "Usage: sff <destination> (e.g. sff host:/tmp/)"
    return 1
  fi
  command -v scp >/dev/null 2>&1 || { echo "sff requires the Fedora OpenSSH client"; return 127; }

  local file
  file="$(find . -type f -printf '%T@\t%p\n' | sort -rn | cut -f2- | ff)" || return
  [[ -n "${file}" ]] && scp "${file}" "$1"
}

open() (
  xdg-open "$@" >/dev/null 2>&1 &
)

rsw() {
  (( $# == 2 )) || { echo "Usage: rsw <source> <destination>"; return 1; }
  command -v ssh >/dev/null 2>&1 || { echo "rsw requires the Fedora OpenSSH client"; return 127; }
  command -v rsync >/dev/null 2>&1 || { echo "rsw requires rsync; install with --with-sync-tools"; return 127; }
  command -v inotifywait >/dev/null 2>&1 || { echo "rsw requires inotify-tools; install with --with-sync-tools"; return 127; }

  local src="${1%/}" dest="$2"
  local sockets="${XDG_RUNTIME_DIR:-${HOME}/.ssh/sockets}"
  mkdir -p "${sockets}"
  local rsh="ssh -o ControlMaster=auto -o ControlPath=${sockets}/rsw-%r@%h:%p -o ControlPersist=yes"

  setsid --fork env RSYNC_RSH="${rsh}" bash -c \
    'rsync -a "$1/" "$2"; while inotifywait -r -q -e modify,create,delete,move "$1"; do rsync -a "$1/" "$2"; done' \
    rsw-watch "${src}" "${dest}" >/dev/null 2>&1
  echo "Watching ${src} -> ${dest}"
}

lsw() {
  local pid cmd rest found=0
  while read -r pid cmd; do
    rest="${cmd##*rsw-watch }"
    echo "${pid}: ${rest% *} -> ${rest##* }"
    found=1
  done < <(pgrep -af 'rsw-watch ')
  (( found )) || echo "No active watches"
}

dsw() {
  local pid found=0
  for pid in $(pgrep -f 'rsw-watch '); do
    kill -- -"${pid}" 2>/dev/null && echo "Stopped watch (pid ${pid})" && found=1
  done
  (( found )) || echo "No active watches"
}

n() {
  if (( $# == 0 )); then
    command nvim .
  else
    command nvim "$@"
  fi
}

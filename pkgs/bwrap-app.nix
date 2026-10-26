# Build a bubblewrap sandbox wrapper around a GUI program, after oxalica's pkgs/prismlauncher-bwrap.nix
# (https://github.com/oxalica/nixos-config), with two corrections:
#   - /run is NOT bound wholesale. A read-only bind does not stop connect() on the unix sockets below it,
#     so the session bus, the gpg-agent (YubiKey signing) and PipeWire would stay reachable. Only the
#     sockets a program needs are bound, one by one, into a private runtime directory.
#   - $HOME is an empty tmpfs; only the program's own directories are bound into it.
#
# What the program gets: the Nix store and /etc read-only, its own home directories, the Wayland socket
# (X11 is withheld: no DISPLAY, no X socket), and optionally the network, the GPU, the PulseAudio socket,
# the Downloads folder, or the files named on its command line. What it does not get: the rest of $HOME,
# other users, the D-Bus session bus (unless dbusTalk/dbusOwn name services: then a filtered connection that
# shows only those), the gpg/ssh agents, other processes (own PID namespace) and the controlling terminal (new
# session).
# Programs that sandbox themselves (Firefox's content processes) keep doing so: bubblewrap leaves nested
# user namespaces available.
{
  lib,
  bubblewrap,
  xdg-dbus-proxy,
  coreutils,
  gnused,
  runtimeShell,
  writeScript,
  runCommandLocal,
}:
{
  pname,
  # The package whose share/ (desktop entries, icons) the wrapper links, so menus and file associations work.
  package,
  # Absolute path of the program started inside the sandbox.
  program,
  # Name of the command this wrapper provides in bin/ (desktop entries call it by this name).
  binName,
  network ? false,
  gpu ? false,
  audio ? false,
  # Bind the XDG download folder read-write (XDG_DOWNLOAD_DIR from ~/.config/user-dirs.dirs).
  downloads ? false,
  # Directories under $HOME the program may write (created when missing).
  homeDirs ? [ ],
  # Files or directories under $HOME the program may read, when they exist (themes, settings).
  homeDirsRo ? [ ],
  # Document viewers: bind each existing file named on the command line read-only, at its real path.
  openFiles ? false,
  # Session-bus services the program may call (dbusTalk) or own (dbusOwn), through a filtered connection
  # (xdg-dbus-proxy, as Flatpak does it); nothing else on the bus is visible. "org.example.*" covers subnames.
  dbusTalk ? [ ],
  dbusOwn ? [ ],
  extraBwrapArgs ? [ ],
  meta ? { },
}:
let
  q = lib.escapeShellArg;
  script = writeScript "${pname}-sandbox" ''
    #!${runtimeShell}
    set -euo pipefail
    # The wrapper's own helpers come from the store; the sandboxed program gets the caller's PATH back.
    orig_path=''${PATH:-}
    export PATH=${lib.makeBinPath [ coreutils gnused ]}
    : "''${HOME:?HOME is not set}"
    uid=$(id -u)
    rt=''${XDG_RUNTIME_DIR:-/run/user/$uid}

    args=(
      --unshare-all
      --die-with-parent
      --new-session
      --dev /dev
      --proc /proc
      --tmpfs /tmp
      --ro-bind /nix /nix
      --ro-bind /etc /etc
      --ro-bind-try /run/current-system /run/current-system
      --ro-bind-try /run/nscd /run/nscd
      --tmpfs /home
      --dir "$HOME"
      --perms 0700 --dir /tmp/runtime
      --setenv XDG_RUNTIME_DIR /tmp/runtime
      --setenv PATH "$orig_path"
      --unsetenv DBUS_SESSION_BUS_ADDRESS
      --unsetenv DISPLAY
      --unsetenv XAUTHORITY
      --unsetenv SSH_AUTH_SOCK
      --unsetenv GPG_TTY
    )
    ${lib.optionalString network ''
      args+=(--share-net --ro-bind-try /run/systemd/resolve /run/systemd/resolve)
    ''}
    ${lib.optionalString gpu ''
      args+=(--ro-bind /sys /sys --dev-bind-try /dev/dri /dev/dri --ro-bind-try /run/opengl-driver /run/opengl-driver)
    ''}

    # Wayland only (X11 lets any client read every other client's input and screen).
    if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      case "$WAYLAND_DISPLAY" in
        /*) sock=$WAYLAND_DISPLAY ;;
        *) sock=$rt/$WAYLAND_DISPLAY ;;
      esac
      if [ -S "$sock" ]; then
        args+=(--ro-bind "$sock" /tmp/runtime/wayland-0 --setenv WAYLAND_DISPLAY wayland-0)
      fi
    fi
    ${lib.optionalString audio ''
      # PulseAudio protocol (served by PipeWire). Note: this socket also allows recording.
      if [ -S "$rt/pulse/native" ]; then
        args+=(--ro-bind "$rt/pulse/native" /tmp/runtime/pulse/native --setenv PULSE_SERVER unix:/tmp/runtime/pulse/native)
      fi
    ''}
    ${lib.optionalString (dbusTalk != [ ] || dbusOwn != [ ]) ''
      # The filtered session bus. The proxy writes one byte to its stdout once it listens and stops when the read
      # end of that pipe closes; bubblewrap holds that end (--sync-fd) while the program runs. The subshell then
      # removes the socket's directory.
      if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        bus_dir=$(mktemp -d "$rt/${pname}-bus.XXXXXX")
        exec {bus_sync}< <(
          ${xdg-dbus-proxy}/bin/xdg-dbus-proxy "$DBUS_SESSION_BUS_ADDRESS" "$bus_dir/bus" --filter \
            ${lib.concatMapStringsSep " " (n: q "--talk=${n}") dbusTalk} ${lib.concatMapStringsSep " " (n: q "--own=${n}") dbusOwn} \
            --fd=1
          rm -rf -- "$bus_dir"
        )
        if read -r -n 1 -u "$bus_sync" _; then
          args+=(--sync-fd "$bus_sync" --ro-bind "$bus_dir/bus" /tmp/runtime/bus)
          args+=(--setenv DBUS_SESSION_BUS_ADDRESS unix:path=/tmp/runtime/bus)
          ${lib.optionalString (lib.elem "org.freedesktop.portal.Desktop" dbusTalk) ''
            # GLib, which opens links for Firefox, uses the portal outside Flatpak only when told to; without
            # it, it looks for a handler inside the sandbox, finds none and fails ("Operation not supported").
            args+=(--setenv GIO_USE_PORTALS 1)
          ''}
        else
          echo "${pname}: the D-Bus proxy did not start; running without the session bus" >&2
        fi
      fi
    ''}
    for d in ${lib.concatMapStringsSep " " q homeDirs}; do
      mkdir -p -- "$HOME/$d"
      args+=(--bind "$HOME/$d" "$HOME/$d")
    done
    for d in ${lib.concatMapStringsSep " " q homeDirsRo}; do
      args+=(--ro-bind-try "$HOME/$d" "$HOME/$d")
    done
    ${lib.optionalString downloads ''
      dl=""
      if [ -r "$HOME/.config/user-dirs.dirs" ]; then
        dl=$(sed -n 's/^XDG_DOWNLOAD_DIR="\(.*\)"$/\1/p' "$HOME/.config/user-dirs.dirs" | head -n 1)
        dl=''${dl//\$HOME/$HOME}
      fi
      [ -n "$dl" ] && [ "$dl" != "$HOME" ] || dl=$HOME/Downloads
      mkdir -p -- "$dl"
      args+=(--bind "$dl" "$dl" --ro-bind-try "$HOME/.config/user-dirs.dirs" "$HOME/.config/user-dirs.dirs")
    ''}

    argv=()
    for a in "$@"; do
      ${lib.optionalString openFiles ''
        # Desktop entries may pass file:// URLs; turn local ones into paths.
        case "$a" in
          file://*) a=''${a#file://}; a=$(printf '%b' "''${a//%/\\x}") ;;
        esac
        if [ -f "$a" ]; then
          a=$(realpath -- "$a")
          args+=(--ro-bind "$a" "$a")
        fi
      ''}
      argv+=("$a")
    done

    exec ${bubblewrap}/bin/bwrap "''${args[@]}" ${lib.escapeShellArgs extraBwrapArgs} -- ${q program} "''${argv[@]}"
  '';
in
runCommandLocal "${pname}-bwrap"
  {
    passthru = { inherit package program; };
    meta = (package.meta or { }) // meta;
  }
  ''
    mkdir -p $out/bin
    ln -s ${script} $out/bin/${binName}
    if [ -d ${package}/share ]; then ln -s ${package}/share $out/share; fi
  ''

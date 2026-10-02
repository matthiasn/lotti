#!/usr/bin/env bash
#
# Helpers shared by build_appimage.sh and check_appimage.sh. Source it; it is
# not meant to be run.

die() {
  echo "error: $*" >&2
  exit 1
}

log() {
  echo "==> $*"
}

# True for a regular file (not a symlink) that starts with the ELF magic.
is_elf() {
  [[ -f "$1" && ! -L "$1" ]] &&
    [[ "$(head -c 4 "$1" | od -An -c | tr -d ' ')" == '177ELF' ]]
}

# Prints gstreamer-plugins.txt as one "required NAME" or "optional NAME" per
# line, with comments and blank lines dropped.
gst_plugin_list() {
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    if [[ "$line" == \?* ]]; then
      echo "optional ${line#\?}"
    else
      echo "required $line"
    fi
  done <"$1"
}

# Fails unless every required plugin from the list file is in the given
# plugin directory, together with video conversion from either the merged
# videoconvertscale plugin (GStreamer 1.22+) or the older videoconvert.
verify_gst_plugins() {
  local dir="$1" list="$2" kind name problems=0
  while read -r kind name; do
    [[ "$kind" == required ]] || continue
    if [[ ! -e "$dir/libgst$name.so" ]]; then
      echo "  required GStreamer plugin '$name' is missing from $dir" >&2
      problems=$((problems + 1))
    fi
  done < <(gst_plugin_list "$list")
  if [[ ! -e "$dir/libgstvideoconvertscale.so" && ! -e "$dir/libgstvideoconvert.so" ]]; then
    echo "  neither the videoconvertscale nor the videoconvert plugin is in $dir" >&2
    problems=$((problems + 1))
  fi
  [[ $problems -eq 0 ]] || die "$problems GStreamer plugin problem(s)"
}

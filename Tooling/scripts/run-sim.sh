#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
# shellcheck source=capabilities.sh
source "$SCRIPT_DIR/capabilities.sh"

usage() {
  cat <<'EOF'
Usage: run-sim.sh [--] [launch-arg ...]

Build with xcodebuild for the configured simulator, install, and launch the app
with optional process launch arguments.

Note: run-sim always uses xcodebuild (needed for a local .app + simctl), even when
Tooling/runtime.yml backend.prefer selects another adapter for just build/test.

Examples:
  just run-sim
  just run-sim -- -ShowPaywall
  just run-sim -- -ScreenshotPhase allClear
EOF
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; ARGS+=("$@"); break ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

validate_runtime_config
require_runtime_tool python3
SCHEME="$(scheme_name)"
[[ -n "$SCHEME" ]] || { echo "scheme missing — set Tooling/runtime.yml scheme" >&2; exit 1; }

PROJ="$(find_xcodeproj)"
WS="$(find_xcworkspace)"
DEST="$(destination_spec)"
SIM="$(sim_name)"
PREFER="$(cfg_get backend.prefer auto)"
if [[ "$PREFER" != "auto" && "$PREFER" != "xcodebuild" ]]; then
  echo "run-sim: note — backend.prefer=$PREFER is ignored here; run-sim uses xcodebuild for simctl install/launch" >&2
fi

DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/harness-run-sim.XXXXXX")"
cleanup() { rm -rf "$DERIVED"; }
trap cleanup EXIT

XB_ARGS=(-scheme "$SCHEME" -destination "$DEST" -configuration Debug -derivedDataPath "$DERIVED")
while IFS= read -r flag; do XB_ARGS+=("$flag"); done < <(xcodebuild_validation_flags)
XB_ARGS+=(build)
if [[ -n "$WS" ]]; then
  XB_ARGS=(-workspace "$WS" "${XB_ARGS[@]}")
elif [[ -n "$PROJ" ]]; then
  XB_ARGS=(-project "$PROJ" "${XB_ARGS[@]}")
else
  echo "no .xcodeproj / .xcworkspace found" >&2
  exit 1
fi

# Record tracked snapshots around the build, including unstaged deletions.
# Symlinks use link text; gitlinks use the checked-out (or indexed) commit.
worktree_identity() {
  local root="$1" manifest="$2" head entry mode object path full line entries tree
  if ! head="$(git -C "$root" rev-parse HEAD 2>/dev/null)"; then
    git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 1
    echo "run-sim: cannot read checkout HEAD" >&2
    return 2
  fi
  local index_file="$DERIVED/.identity-index"
  git -C "$root" ls-files -s -z >"$index_file" || { echo "run-sim: cannot enumerate tracked paths" >&2; return 2; }
  : >"$manifest" || return 2
  entries=""
  while IFS= read -r -d '' entry; do
    mode="${entry%% *}"
    object="${entry#* }"
    object="${object%% *}"
    path="${entry#*$'\t'}"
    full="$root/$path"
    if [[ "$mode" == 160000 ]]; then
      if [[ -e "$full/.git" ]]; then
        if ! object="$(git -C "$full" rev-parse HEAD 2>/dev/null)"; then
          echo "run-sim: cannot read tracked path: $path (submodule HEAD unreadable)" >&2
          return 2
        fi
      fi
      line="gitlink $object  $path"
    elif [[ -L "$full" ]]; then
      line="$(readlink -- "$full" | shasum -a 256 | awk '{print $1}')  $path" || return 2
    elif [[ -f "$full" ]]; then
      line="$(cd "$root" && shasum -a 256 -- "$path")" || return 2
      if [[ -z "$line" ]]; then
        echo "run-sim: cannot read tracked path: $path" >&2
        return 2
      fi
    elif [[ ! -e "$full" ]]; then
      line="deleted  $path"
    else
      echo "run-sim: cannot read tracked path: $path (not a file)" >&2
      return 2
    fi
    printf '%s\0%s\0' "$path" "$line" >>"$manifest" || return 2
    entries+="$line"$'\n'
  done <"$index_file"
  tree="$(printf '%s' "$entries" | shasum -a 256 | awk '{print $1}')" || return 2
  [[ -n "$tree" ]] || return 1
  printf '%s:%s\n' "$head" "$tree"
}

BUILD_IDENTITY=""
if BUILD_IDENTITY="$(worktree_identity "$(project_root)" "$DERIVED/.identity-before")"; then
  :
else
  identity_status=$?
  if ((identity_status == 2)); then
    echo "run-sim: build-identity marker failed — see the tracked-path error above" >&2
    exit 1
  fi
  echo "run-sim: note — $(project_root) is not a git checkout; build-identity marker skipped" >&2
fi

echo "run-sim: build $SCHEME → $SIM"
if have xcbeautify; then
  xcodebuild "${XB_ARGS[@]}" | xcbeautify
else
  xcodebuild "${XB_ARGS[@]}"
fi

APP_PATH="$(
  python3 - "$DERIVED" "$SCHEME" <<'PY'
import os, sys
derived, scheme = sys.argv[1], sys.argv[2]
products = os.path.join(derived, "Build", "Products")
if not os.path.isdir(products):
    raise SystemExit(0)
preferred = []
others = []
for root, dirs, _files in os.walk(products):
    # Prefer top-level products, not nested copies inside other bundles
    depth = root[len(products):].count(os.sep)
    for d in list(dirs):
        if not d.endswith(".app"):
            continue
        path = os.path.join(root, d)
        if depth <= 2:
            (preferred if d == f"{scheme}.app" else others).append(path)
        dirs.remove(d)
if preferred:
    print(preferred[0])
elif others:
    # Prefer iphonesimulator products over others
    others.sort(key=lambda p: (0 if "iphonesimulator" in p else 1, len(p)))
    print(others[0])
PY
)"
[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || { echo "no .app produced under $DERIVED (expected ${SCHEME}.app)" >&2; exit 1; }

if [[ -n "$BUILD_IDENTITY" ]]; then
  after_build="$(worktree_identity "$(project_root)" "$DERIVED/.identity-after")" || exit 1
  changed_paths="$(python3 - "$DERIVED/.identity-before" "$DERIVED/.identity-after" <<'CHANGES'
import json
import os
from pathlib import Path
import sys


def snapshot(path):
    entries = Path(path).read_bytes().split(b"\0")[:-1]
    return dict(zip(entries[::2], entries[1::2]))


before, after = (snapshot(path) for path in sys.argv[1:])
print(json.dumps([os.fsdecode(path) for path in sorted(before.keys() | after.keys())
                 if before.get(path) != after.get(path)]))
CHANGES
)"
  if [[ "$after_build" != "$BUILD_IDENTITY" ]]; then
    echo "run-sim: tracked state changed during build: $changed_paths" >&2
    echo "run-sim: recording both snapshots; marker does not prove exact compiler inputs" >&2
  fi
  BUILD_IDENTITY="$(printf '%s\npost-build: %s\nchanged-during-build: %s' "$BUILD_IDENTITY" "$after_build" "$changed_paths")"
  printf '%s\n' "$BUILD_IDENTITY" >"$APP_PATH/.runtime-build-identity"
fi

BUNDLE_ID="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null \
    || plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null \
    || true
)"
[[ -n "$BUNDLE_ID" ]] || { echo "could not read CFBundleIdentifier from $APP_PATH/Info.plist" >&2; exit 1; }

UDID="$(sim_udid)"
# Never fall back to "booted": with several apps' sessions on one Mac that is
# whichever device booted first, often another app's. No GUI is opened either;
# the host's simulator panel or DeviceHub shows the device (Xcode 27 has no
# Simulator.app, and opening one would pull focus from every session).
[[ -n "$UDID" ]] || { echo "run-sim: could not resolve the app's own simulator ($SIM)" >&2; exit 1; }

echo "run-sim: boot simulator $SIM"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

TARGET="$UDID"
echo "run-sim: install $APP_PATH ($BUNDLE_ID)"
xcrun simctl install "$TARGET" "$APP_PATH"

if [[ -n "$BUILD_IDENTITY" ]]; then
  INSTALLED_PATH="$(xcrun simctl get_app_container "$TARGET" "$BUNDLE_ID" app 2>/dev/null || true)"
  INSTALLED_IDENTITY="$(cat "${INSTALLED_PATH:-/dev/null}/.runtime-build-identity" 2>/dev/null || true)"
  if [[ "$INSTALLED_IDENTITY" != "$BUILD_IDENTITY" ]]; then
    echo "run-sim: installed bundle does not match the build this worktree just produced" >&2
    echo "  built:     $BUILD_IDENTITY" >&2
    echo "  installed: ${INSTALLED_IDENTITY:-<none>}" >&2
    exit 1
  fi
fi

echo "run-sim: launch $BUNDLE_ID ${ARGS[*]:-}"
if [[ ${#ARGS[@]} -gt 0 ]]; then
  xcrun simctl launch "$TARGET" "$BUNDLE_ID" "${ARGS[@]}"
else
  xcrun simctl launch "$TARGET" "$BUNDLE_ID"
fi

echo "run-sim OK"

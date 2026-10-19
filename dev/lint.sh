#!/usr/bin/env bash
# Static checks for the repo: bash syntax, shellcheck, and qmllint.
#
# qmllint needs help resolving Quickshell's "qs.*" import namespace: Quickshell
# maps the config root to the module name "qs", which qmllint does not know.
# We therefore mirror shell/ into a temp "qs" tree, generate a qmldir per
# directory and point qmllint at it. A handful of warnings are false positives
# caused by Quickshell's dynamically-registered types (PanelWindow is marked
# uncreatable, BluetoothAdapter is not exposed declaratively, attached props,
# etc.) and are disabled below so only real problems fail the build.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SCRIPTS=(install.sh bin/vibeshell dev/run-nested.sh dev/sbx.sh dev/screenshots.sh dev/test.sh dev/lint.sh)
SHELLCHECK="${SHELLCHECK:-shellcheck}"
FAIL=0

# Prefer Qt6's qmllint; on Arch with qt5-declarative installed the plain
# "qmllint" on $PATH is the old Qt 5 one which does not know our warning flags.
if [ -n "${QMLLINT:-}" ]; then
  QMLLINT_BIN="$QMLLINT"
elif [ -x /usr/lib/qt6/bin/qmllint ]; then
  QMLLINT_BIN=/usr/lib/qt6/bin/qmllint
else
  QMLLINT_BIN=qmllint
fi

echo "== bash -n =="
for f in "${SCRIPTS[@]}"; do
  if bash -n "$f"; then echo "  ok   $f"; else echo "  FAIL $f"; FAIL=1; fi
done

echo "== shellcheck =="
if command -v "$SHELLCHECK" >/dev/null 2>&1; then
  if "$SHELLCHECK" --severity=warning "${SCRIPTS[@]}"; then echo "  ok"; else FAIL=1; fi
else
  echo "  skip (shellcheck not installed)"
fi

echo "== qmllint =="
if [ -x "$QMLLINT_BIN" ] || command -v "$QMLLINT_BIN" >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cp -r shell "$tmp/qs"
  while IFS= read -r d; do
    rel="${d#"$tmp"/}"
    mod="${rel//\//.}"
    {
      echo "module $mod"
      shopt -s nullglob
      for f in "$d"/*.qml; do
        b="$(basename "$f" .qml)"
        base="$(basename "$f")"
        if grep -q "pragma Singleton" "$f"; then
          echo "singleton $b 0.1 $base"
        else
          echo "$b 0.1 $base"
        fi
      done
    } > "$d/qmldir"
  done < <(find "$tmp/qs" -type d)

  qmlfail=0
  count=0
  while IFS= read -r f; do
    count=$((count + 1))
    if ! "$QMLLINT_BIN" \
      -I "$tmp" \
      --unqualified disable \
      --missing-property disable \
      --uncreatable-type disable \
      --unresolved-type disable \
      --unused-imports disable \
      "$f"; then
      qmlfail=1
    fi
  done < <(find "$tmp/qs" -name '*.qml' | sort)
  if [ "$qmlfail" -eq 0 ]; then echo "  ok   $count files"; else echo "  FAIL qmllint"; FAIL=1; fi
else
  echo "  skip (qmllint not installed)"
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "lint: OK"; else echo "lint: FAILED"; fi
exit "$FAIL"

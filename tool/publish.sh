#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./tool/publish.sh [--dry-run | --publish] [--fvm]

Run dependency resolution, format checks, analysis, tests, and a pub.dev dry run.

  --dry-run  Validate the package without uploading it (default).
  --publish  Also publish after all checks pass, with Dart's confirmation prompt.
  --fvm      Use "fvm dart" instead of "dart".
  -h, --help Show this help.
EOF
}

mode=''
dart_command=(dart)
for argument in "$@"; do
  case "$argument" in
    --dry-run|--publish)
      if [[ -n "$mode" && "$mode" != "$argument" ]]; then
        echo 'Error: --dry-run and --publish cannot be used together.' >&2
        exit 2
      fi
      mode="$argument"
      ;;
    --fvm) dart_command=(fvm dart) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown argument: $argument" >&2; usage >&2; exit 2 ;;
  esac
done

if ! command -v "${dart_command[0]}" >/dev/null 2>&1; then
  echo "Error: ${dart_command[0]} is not available on PATH." >&2
  exit 1
fi

package_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$package_root"

run_dart() {
  printf '\n>'
  printf ' %s' "${dart_command[@]}" "$@"
  printf '\n'
  "${dart_command[@]}" "$@"
}

run_dart pub get
run_dart format --output=none --set-exit-if-changed lib bin test tool example
run_dart analyze
run_dart test
run_dart pub publish --dry-run

if [[ "$mode" == '--publish' ]]; then
  run_dart pub publish
else
  printf '\nDry run complete. To publish, run: ./tool/publish.sh --publish'
  if [[ "${dart_command[0]}" == 'fvm' ]]; then
    printf ' --fvm'
  fi
  printf '\n'
fi

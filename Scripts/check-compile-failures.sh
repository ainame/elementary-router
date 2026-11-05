#!/bin/sh
# Checks that misuse of the typed destination API fails to compile in a downstream package.
#
# Builds the `ValidUsage` positive control in Tests/CompileChecks, then builds each `Rejects*`
# target and requires it to fail with an error, reported in that target's source file, matching
# the extended regular expression on the file's `// expected-error:` line.
#
# Set SWIFT to override the driver, for example `SWIFT="xcrun swift"`.
set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
package="$root/Tests/CompileChecks"
swift_command="${SWIFT:-swift}"

if ! $swift_command build --package-path "$package" --target ValidUsage; then
  echo "error: the ValidUsage positive control failed to build" >&2
  exit 1
fi

status=0
checked=0
for directory in "$package"/Sources/Rejects*; do
  target="$(basename "$directory")"
  source="$directory/$target.swift"
  pattern="$(sed -n 's|^// expected-error: ||p' "$source")"
  if [ -z "$pattern" ]; then
    echo "error: $source has no '// expected-error:' line" >&2
    status=1
    continue
  fi

  checked=$((checked + 1))
  if output="$($swift_command build --package-path "$package" --target "$target" 2>&1)"; then
    echo "error: $target compiled, but it must be rejected" >&2
    status=1
  elif printf '%s\n' "$output" | grep -Eq "$target\.swift:[0-9]+:[0-9]+: error: .*($pattern)"; then
    echo "ok: $target is rejected"
  else
    printf '%s\n' "$output" >&2
    echo "error: $target failed without an error matching '$pattern' in $target.swift" >&2
    status=1
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "error: no Rejects* targets found in $package/Sources" >&2
  exit 1
fi

exit "$status"

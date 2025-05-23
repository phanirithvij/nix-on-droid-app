{
  lib,
  writeShellScriptBin,
  git,
  gradle2nix,
  gradle,
  jdk,
  extraGradleFlags,
}:

writeShellScriptBin "update-locks" ''
  set -eu -o pipefail

  cd "$(${lib.getExe git} rev-parse --show-toplevel)"

  ${lib.getExe gradle2nix} \
    --gradle-home=${gradle}/lib/gradle \
    --gradle-jdk=${jdk.home} \
    ${lib.strings.concatStringsSep " " extraGradleFlags}
    -- --write-locks
''

{
  lib,
  jq,
  htmlq,
  gawk,
  gnused,
  gnugrep,
  gradle,
  fetchurl,
  parallel,
  moreutils,
  writeShellScriptBin,
  go-maven-resolver,
  callPackage,
}:
let
  url2json = callPackage ./url2json.nix { };
  resolve-gradle-deps = writeShellScriptBin "resolve-gradle-deps" ''
    # generate dependency report from current project
    pushd "$(git rev-parse --show-toplevel)" >/dev/null || exit 1

    if [ -z "$1" ]; then
        # gather a full dependency report
        ${lib.getExe gradle} -I nix/init.gradle \
          --no-daemon --dependency-verification=off \
          --no-configuration-cache --no-configure-on-demand \
          :ForceDependencyResolutionPlugin_resolveAllDependencies >/dev/null 2>&1 || exit 1
    fi

    popd >/dev/null || exit 1
  '';
  gen-deps-lock = writeShellScriptBin "gen-deps-lock" ''
    pushd "$(git rev-parse --show-toplevel)" >/dev/null || exit 1

    out=''${2:-nix/gradle.lock}
    export PATH=${
      lib.makeBinPath [
        gawk
        gnused
        gnugrep
        moreutils # sponge
        jq
        htmlq
        go-maven-resolver
      ]
    }:$PATH

    # trim/format input file properly
    deps_list="$(grep . "$1" | awk '{$1=$1};1')"

    echo "[" >"$out"

    # note: moreutils parallel doesn't work here
    echo -en "$deps_list" | go-maven-resolver | \
      ${lib.getExe parallel} --will-cite --keep-order --jobs 4 ${lib.getExe url2json} >>"$out"

    # convert to gradle2nix lock format
    # TODO fork and modify go-maven-resolver to generate/modify gradle.lock instead
    grep . "$out" | sed '$s/,$/\n]/' | jq -r 'map(. as $root | {
          (.path | split("/") | (.[0:-2] | join(".")) + ":" + .[-2] + ":" + .[-1]): (.files | to_entries | map({
              (.key): {
                  url: ($root.repo + "/" + $root.path + "/" + .key),
                  hash: .value.sha256
              }
          }) | add)
      }) | add' | jq -S . | sponge "$out"

    popd >/dev/null || exit 1
  '';
  build-apk = writeShellScriptBin "build-apk" (builtins.readFile ./build.sh);
in
{
  inherit gen-deps-lock resolve-gradle-deps build-apk;
}

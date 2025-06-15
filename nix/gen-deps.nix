{
  lib,
  jq,
  htmlq,
  gradle,
  fetchurl,
  parallel,
  writeShellScriptBin,
  # writeText,
  stdenv,
  go-maven-resolver,
}:
let
  # cmd to gather all dependencies
  gradleCmd = ''
    ${lib.getExe gradle} -I init.gradle \
      --no-daemon --dependency-verification=off \
      --no-configuration-cache --no-configure-on-demand \
      :ForceDependencyResolutionPlugin_resolveAllDependencies >/dev/null 2>&1 || exit 1
  '';
  patch = ./url2json-add-id.patch;
  url2json = stdenv.mkDerivation {
    name = "url2json";
    phases = [ "buildPhase" ];
    src = fetchurl {
      url = "https://github.com/status-im/status-mobile/raw/2df7a7cf6d46c8d1add73b8965ce8b04e6f7d014/nix/deps/gradle/url2json.sh";
      hash = "sha256-McEyQPvofpMYv7mvX/7m/eRNYxJOUkm98foSYmYOyE4=";
      executable = true;
    };
    buildPhase = ''
      mkdir -p $out/bin; cd $out/bin
      cp $src url2json.sh
      chmod +w url2json.sh; patch < ${patch}; chmod -w url2json.sh
      mv url2json.sh url2json
    '';
    meta.mainProgram = "url2json";
  };
in
writeShellScriptBin "gen-deps" ''
  pushd "$(git rev-parse --show-toplevel)" >/dev/null || exit 1

  report_path="$1"
  if [ -z "$1" ]; then
      # generate dependency report from current project
      report_path="build/reports/dependency-graph-snapshots/dependency-list.txt"
      ${gradleCmd}
  fi

  export PATH=$PATH:${htmlq}/bin
  ${lib.getExe go-maven-resolver} < "$report_path" | \
    ${lib.getExe parallel} \
       --will-cite --keep-order --jobs 4 \
       ${lib.getExe url2json} \
    | grep . | sed '$s/,$//' | \
  # TODO f this shit, fork and modify the go code above to generate gradle.lock
    ${lib.getExe jq} -r '. as $root | 
      "\"" + (.path | split("/") | (.[0:-2] | join(".")) + ":" + .[-2] + ":" + .[-1]) + "\": " +
      (.files | to_entries | map(
        "    \"" + .key + "\": {\n" +
        "      \"url\": \"" + ($root.repo + "/" + $root.path + "/" + .key) + "\",\n" +
        "      \"hash\": \"" + .value.sha256 + "\"\n" +
        "    }"
      ) | "{\n" + join(",\n") + "\n  },")'

  popd >/dev/null || exit 1
''

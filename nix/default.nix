{
  pkgs ? import <nixpkgs> { config.allowUnfree = true; },
  jdk,
  gradle,
  androidsdk,
  ...
}:
let
  buildMavenRepo = pkgs.callPackage ./maven-repo.nix { };
  mavenRepo = buildMavenRepo {
    name = "nix-maven-repo";
    repos = [
      "https://jitpack.io"
      "https://dl.google.com/dl/android/maven2"
      "https://repo.maven.apache.org/maven2"
      "https://maven.pkg.jetbrains.space/kotlin/p/kotlin/dev"
      "https://plugins.gradle.org/m2"
    ];
    deps = builtins.fromJSON (builtins.readFile ./deps.json);
  };
in
import ./build.nix {
  inherit (pkgs) stdenv;
  inherit
    mavenRepo
    androidsdk
    jdk
    gradle
    ;
}

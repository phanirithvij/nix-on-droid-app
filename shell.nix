{
  sources ? import ./npins,
  lib ? pkgs.lib,
  pkgs ? import sources.nixpkgs {
    config.android_sdk.accept_license = true;
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "android-sdk-platform-tools"
        "android-sdk-cmdline-tools"
        "android-sdk-build-tools"
        "android-sdk-platforms"
        "android-sdk-tools"

        "android-sdk-ndk"
        "android-sdk-ndk-bundle"
      ];
  },
}:
let
  jdk = pkgs.jdk11_headless;
  # note: can use pkgs.androidenv.androidPkgs.androidsdk
  # but it pulls in lots of toolchains see https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/mobile/androidenv/default.nix#L18
  androidSdk' = (
    pkgs.androidenv.composeAndroidPackages {
      includeNDK = true;
      ndkVersions = [
        "22.1.7171670"
        "23.1.7779620"
      ];
      platformVersions = [
        "28"
        "30"
      ];
      buildToolsVersions = [ "30.0.3" ];
      includeEmulator = false;
      includeSystemImages = false;
    }
  );
  sdk = androidSdk'.androidsdk;
  platformTools = androidSdk'.platform-tools;

  ANDROID_SDK_ROOT = "${sdk}/libexec/android-sdk";
  ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";
in
pkgs.mkShellNoCC {
  packages = [
    platformTools
    sdk
    jdk
  ];
  JAVA_HOME = jdk;
  inherit
    ANDROID_SDK_ROOT
    ANDROID_NDK_ROOT
    ;
}

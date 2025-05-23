{
  description = "A flake to build nix-on-droid apk";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-compat.url = "github:edolstra/flake-compat";
    # android-nixpkgs.url = "github:tadfisher/android-nixpkgs/stable";
    # android-nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
    # can't get it to work with ndk, hit https://github.com/tadfisher/android-nixpkgs/issues/113
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux"; # TODO iter attrs over [ aarch64-darwin x86_64-darwin x86_64-linux]
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs {
        inherit system;
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
      };
      android = pkgs.androidenv.composeAndroidPackages {
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
      };
      jdk = pkgs.jdk11_headless;
      # need to use gradle unwrapped to allow passing --console=plain?
      # https://github.com/tadfisher/gradle2nix/pull/78
      # https://github.com/tadfisher/gradle2nix/commit/dff8e5bc4cff0257d2edb54b074f6cbc858307be
      # gradle = pkgs.gradle_7.unwrapped;
      # gradleGen provides the unwrapped version
      gradle = pkgs.callPackage (pkgs.gradleGen {
        version = "7.5";
        hash = "sha256-y4fyIsVYW9RoOK1Nt4RjpcXz0zbl4rmNx8DFhlJzUcI=";
        defaultJava = jdk;
      }) { };
      updateLocks = pkgs.callPackage ./nix/update-locks.nix { inherit gradle; };
    in
    {
      packages.${system} = {
        inherit (android) androidsdk;
        hello = nixpkgs.legacyPackages.${system}.hello;
        inherit gradle;
        default = import ./nix {
          # TODO use newScope or overlays like status-im app does
          inherit (android) androidsdk;
          inherit jdk gradle pkgs;
        };
      };
      devShells.${system}.default = pkgs.mkShellNoCC {
        JAVA_HOME = jdk.home;
        ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        ANDROID_NDK_ROOT = "${android.androidsdk}/ndk-bundle";
        packages = [
          updateLocks
          android.androidsdk
          android.platform-tools
          gradle
          jdk
        ];
      };
    };
}

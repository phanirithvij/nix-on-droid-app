{
  description = "A flake to build nix-on-droid apk";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-compat.url = "github:edolstra/flake-compat";
    gradle2nix.url = "github:phanirithvij/gradle2nix/v2";
    # android-nixpkgs.url = "github:tadfisher/android-nixpkgs/stable";
    # android-nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
    # can't get it to work with ndk, hit https://github.com/tadfisher/android-nixpkgs/issues/113
  };

  outputs =
    { nixpkgs, gradle2nix, ... }:
    let
      system = "x86_64-linux"; # TODO iter attrs over [ aarch64-darwin x86_64-darwin x86_64-linux]
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs {
        inherit system;
        config.android_sdk.accept_license = true;
        config.allowUnfree = true;
      };
      buildToolsVersion = "30.0.3";
      android = pkgs.androidenv.composeAndroidPackages {
        includeNDK = true;
        ndkVersions = [
          "22.1.7171670"
          "23.1.7779620"
          # "21.1.6352462" # jitpack_ndk_version ?
        ];
        platformVersions = [
          "28"
          "30"
        ];
        buildToolsVersions = [ buildToolsVersion ];
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

      # https://github.com/Cliquets/scrcpy/blob/main/flake.nix
      extraGradleFlags = [
        "--offline"
        "--no-daemon"
        "-Dorg.gradle.project.android.aapt2FromMavenOverride=${android.androidsdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/aapt2"
      ];
      overrideGradleFlags =
        drv:
        drv.overrideAttrs (prev: {
          gradleFlags = (prev.gradleFlags or [ ]) ++ extraGradleFlags;
        });
      buildGradlePackage =
        args: overrideGradleFlags (gradle2nix.builders.${system}.buildGradlePackage args);

      # TODO use newScope or overlays like status-im app does
      updateLocks = pkgs.callPackage ./nix/update-locks.nix {
        inherit gradle jdk extraGradleFlags;
        gradle2nix = gradle2nix.packages.${system}.default;
      };
    in
    {
      packages.${system} = {
        default = buildGradlePackage {
          pname = "nix-on-droid-app";
          version = "0.118.3";
          src = lib.cleanSource ./.;
          lockFile = ./gradle.lock;

          inherit gradle;
          buildJdk = jdk;

          ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${android.androidsdk}/ndk-bundle";
          nativeBuildInputs = [ android.androidsdk ];
          gradleBuildFlags = [ "assembleRelease" ];

          installPhase = ''
            mkdir -p $out/bin
            cp -r build/* $out
          '';
        };
      };
      devShells.${system}.default = pkgs.mkShellNoCC {
        JAVA_HOME = jdk.home;
        ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        ANDROID_NDK_ROOT = "${android.androidsdk}/ndk-bundle";
        packages = [
          jdk
          gradle
          updateLocks
          android.androidsdk
          android.platform-tools
          gradle2nix.packages.${system}.default
        ];
      };
    };
}

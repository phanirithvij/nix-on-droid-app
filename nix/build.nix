{
  stdenv,
  jdk,
  gradle,
  mavenRepo,
  androidsdk,
}:

stdenv.mkDerivation {
  pname = "built-with-gradle";
  version = "0.118.3";

  src = ../.;

  nativeBuildInputs = [ gradle ];

  JDK_HOME = "${jdk.home}";
  ANDROID_SDK_ROOT = "${androidsdk}/libexec/android-sdk";

  buildPhase = ''
    runHook preBuild
    gradle build \
      --offline --no-daemon --no-build-cache --info --full-stacktrace --console=plain \
      --warning-mode=all --parallel \
      -PnixMavenRepo=${mavenRepo} \
      -Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_SDK_ROOT/build-tools/30.0.3/aapt2
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r app/build/outputs/* $out
    runHook postInstall
  '';

  dontStrip = true;
}

# Kasane.app with kasaned inside, unsigned. scripts/sign-app.sh signs a copy of it.
{
  lib,
  stdenv,
  swift,
  swiftpm,
  ja-strings,
}:
stdenv.mkDerivation {
  name = "kasane";

  # Only what the app is built from: a change to the docs or scripts keeps the store path, and with
  # it the installed app and the running kasaned. SwiftPM needs the test target's directory even
  # when it builds no tests.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Package.swift
      ../Sources
      ../Tests
      ../bundle/Info.plist
      ../bundle/AppIcon.icns
    ];
  };

  # swiftpmHook's build phase runs `swift build -c release`, which builds Kasane and kasaned.
  nativeBuildInputs = [
    swift
    swiftpm
  ];

  installPhase = ''
    runHook preInstall
    bin="$(swiftpmBinPath)"
    contents="$out/Applications/Kasane.app/Contents"
    install -D -m 644 bundle/Info.plist "$contents/Info.plist"
    install -D -m 755 -t "$contents/MacOS" "$bin/Kasane" "$bin/kasaned"
    install -D -m 644 -t "$contents/Resources" bundle/AppIcon.icns
    install -D -m 644 ${ja-strings} "$contents/Resources/ja.lproj/Localizable.strings"
    runHook postInstall
  '';
}

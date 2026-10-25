# Installs kasane with nix-darwin: Kasane.app at /Applications/Kasane.app, signed during activation
# with the primary user's signing identity, and kasaned as a LaunchDaemon.
{ self, signingIdentity }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  app = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/Applications/Kasane.app";
in
{
  options.services.kasane.enable = lib.mkEnableOption "kasane, which blocks the built-in keyboard while an external keyboard sits on it";

  config = lib.mkIf config.services.kasane.enable {
    # The signing identity is in the primary user's login keychain.
    system.requiresPrimaryUser = [ "services.kasane.enable" ];

    # extraActivation runs before nix-darwin loads LaunchDaemons, so on a first install kasaned
    # starts after its app is in place.
    system.activationScripts.extraActivation.text = ''
      ${../scripts}/install-app.sh ${lib.escapeShellArg signingIdentity} ${app} ${lib.escapeShellArg config.system.primaryUser}
    '';

    environment.launchDaemons."dev.mei.kasaned.plist".source = ../bundle/dev.mei.kasaned.plist;
  };
}

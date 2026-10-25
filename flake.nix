{
  description = "Blocks a MacBook's built-in keyboard while an external keyboard sits on top of it";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      strings = import ./nix/strings.nix { inherit (nixpkgs) lib; };
      catalog = builtins.fromJSON (builtins.readFile ./bundle/Localizable.xcstrings);
      # The self-signed code signing identity in the login keychain. Input Monitoring and the XPC
      # peer checks rely on every build being signed with it.
      signingIdentity = "kasane code signing";
    in
    {
      packages.${system} = rec {
        default = pkgs.callPackage ./nix/package.nix { inherit ja-strings; };
        # ja.lproj/Localizable.strings, compiled from bundle/Localizable.xcstrings.
        ja-strings = pkgs.writeText "Localizable.strings" (strings.toStrings catalog);
      };

      # `nix run github:mei28/kasane#signing-identity`, once per Mac before the first switch.
      apps.${system}.signing-identity = {
        type = "app";
        program = "${pkgs.writeShellScript "kasane-signing-identity" ''
          exec ${./scripts/create-signing-identity.sh} ${pkgs.lib.escapeShellArg signingIdentity}
        ''}";
        meta.description = "Create the code signing identity kasane is signed with in the login keychain";
      };

      checks.${system}.strings = import ./nix/strings-test.nix { inherit pkgs strings; };

      darwinModules.default = import ./nix/darwin-module.nix { inherit self signingIdentity; };
    };
}

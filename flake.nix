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
    in
    {
      # ja.lproj/Localizable.strings, compiled from bundle/Localizable.xcstrings.
      packages.${system}.ja-strings = pkgs.writeText "Localizable.strings" (strings.toStrings catalog);

      checks.${system}.strings = import ./nix/strings-test.nix { inherit pkgs strings; };
    };
}

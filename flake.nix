{
  description = "Development environment";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # Attrs { system -> pkgs }
      packageUniverse = lib.genAttrs systems (system: import nixpkgs { inherit system; });

      eachSystem = lib.flip lib.mapAttrs packageUniverse;
    in

    {
      devShell = eachSystem (
        system: pkgs:
        pkgs.mkShell {
          packages = [
            (pkgs.presenterm)
            (pkgs.writeScriptBin "hand-wave" ''
              exec presenterm README.md
            '')
          ];
        }
      );
    };
}

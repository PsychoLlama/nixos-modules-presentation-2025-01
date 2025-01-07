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
      packages = eachSystem (
        system: pkgs: {
          default = pkgs.writers.writeBashBin "hand-wave" ''
            exec ${pkgs.presenterm}/bin/presenterm ${./README.md}
          '';
        }
      );

      devShell = eachSystem (
        system: pkgs:
        pkgs.mkShell {
          packages = [
            pkgs.presenterm
            self.packages.${system}.default
          ];
        }
      );
    };
}

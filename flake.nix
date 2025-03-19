{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages = rec {
          godot = pkgs.callPackage ./default.nix { version = "4.4"; };
          default = godot;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            jq
            nixpkgs-fmt
            scons
            python311
          ];
        };
      }
    );
}
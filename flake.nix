{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "4.5-dev";
      in {
        packages = rec {
          godot = pkgs.callPackage ./default.nix { inherit version; };
          godot-mono = pkgs.callPackage ./default.nix {
            inherit version;
            withMono = true;
            nugetDeps = ./deps.json;
          };
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
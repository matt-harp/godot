{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        vInfo = builtins.fromTOML (builtins.readFile ./version.py);
        version = "${toString vInfo.major}.${toString vInfo.minor}.${toString vInfo.patch}-${toString vInfo.status}";
      in {
        packages = rec {
          godot = pkgs.callPackage ./default.nix { inherit version; };

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
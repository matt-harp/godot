{
  description = "Godot Engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          godotPackage = pkgs.callPackage ./package.nix {
            src = self;
          };

          # Create variants with different options
          makeGodotVariant = extraArgs: godotPackage.override extraArgs;

        in
        rec {
          packages.default = packages.godot-editor;

          packages = {
            # Standard editor
            godot-editor = makeGodotVariant {
              buildTarget = "editor";
            };

            # Release template
            godot-template-release = makeGodotVariant {
              buildTarget = "template_release";
            };

            # Debug template
            godot-template-debug = makeGodotVariant {
              buildTarget = "template_debug";
            };
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              pkg-config
              autoPatchelfHook
            ];
            buildInputs = with pkgs; [
              # Godot build dependencies
              scons
              pkg-config
              perl
              python3
              clang
              ccache
              bzip2

              # Development tools
              gdb
              valgrind
            ];
            runtimeDependencies = with pkgs; [
              alsa-lib
              bzip2
              dbus
              fontconfig
              freetype
              glib
              libGL
              libpulseaudio
              xorg.libX11
              xorg.libXcursor
              xorg.libXext
              xorg.libXfixes
              xorg.libXi
              xorg.libXinerama
              libxkbcommon
              xorg.libXrandr
              xorg.libXrender
              speechd-minimal
              udev
              vulkan-loader
              wayland
              wayland-scanner
              zlib
            ];
          };
        };
    };
}

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
            buildInputs = with pkgs; [
              # Godot build dependencies
              scons
              pkg-config
              perl
              python3
              clang
              ccache

              # Runtime dependencies
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

              # Development tools
              gdb
              valgrind
            ];

            shellHook = ''
              echo "Godot development environment"
              echo ""
              echo "Quick commands:"
              echo "  Build editor:           scons -j$(nproc) platform=linuxbsd target=editor use_llvm=yes precision=double"
              echo "  Build release template: scons -j$(nproc) platform=linuxbsd target=template_release use_llvm=yes precision=double"
              echo "  Build debug template:   scons -j$(nproc) platform=linuxbsd target=template_debug use_llvm=yes precision=double"
              echo "  Clean build:            scons -c"
              echo ""
              echo "Nix commands:"
              echo "  nix build .#godot-editor           - Build editor via Nix"
              echo "  nix build .#godot-template-release - Build release template via Nix"
              echo "  nix run .#godot-editor             - Build and run editor"
              echo ""

              # Set up environment
              export CC=clang
              export CXX=clang++
              export CCACHE_DIR="$HOME/.cache/ccache"
              mkdir -p "$CCACHE_DIR"

              # Add helper functions
              godot_build() {
                local target=''${1:-editor}
                local precision=''${2:-double}
                echo "Building Godot with target=$target precision=$precision"
                scons -j$(nproc) platform=linuxbsd target=$target use_llvm=yes precision=$precision ccflags="-fno-strict-aliasing" linkflags="-Wl,--build-id -lbz2"
              }

              godot_run() {
                local binary=$(find bin -name "godot.linuxbsd.editor.*" | head -1)
                if [[ -f "$binary" ]]; then
                  echo "Running: $binary"
                  "$binary" "$@"
                else
                  echo "No editor binary found. Build first with: godot_build editor"
                fi
              }

              export -f godot_build godot_run
            '';
          };
        };
    };
}

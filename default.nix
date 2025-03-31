{
  alsa-lib,
  autoPatchelfHook,
  buildPackages,
  dbus,
  dotnetCorePackages,
  fetchFromGitHub,
  fontconfig,
  installShellFiles,
  lib,
  libdecor,
  libGL,
  libpulseaudio,
  libX11,
  libXcursor,
  libXext,
  libXfixes,
  libXi,
  libXinerama,
  libxkbcommon,
  libXrandr,
  libXrender,
  makeWrapper,
  pkg-config,
  runCommand,
  scons,
  speechd-minimal,
  stdenv,
  stdenvNoCC,
  testers,
  udev,
  version,
  vulkan-loader,
  wayland,
  wayland-scanner,
  withDbus ? true,
  withFontconfig ? true,
  withMono ? false,
  nugetDeps ? null,
  withPlatform ? "linuxbsd",
  withPrecision ? "single",
  withPulseaudio ? true,
  withSpeechd ? true,
  withTarget ? "editor",
  withTouch ? true,
  withUdev ? true,
  # Wayland in Godot requires X11 until upstream fix is merged
  # https://github.com/godotengine/godot/pull/73504
  withWayland ? true,
  withX11 ? true,
}:
assert lib.asserts.assertOneOf "withPrecision" withPrecision [
  "single"
  "double"
];
let
  mkSconsFlagsFromAttrSet = lib.mapAttrsToList (
    k: v: if builtins.isString v then "${k}=${v}" else "${k}=${builtins.toJSON v}"
  );

  suffix = if withMono then "-mono" else "";

  arch = stdenv.hostPlatform.linuxArch;

  dotnet-sdk = dotnetCorePackages.sdk_8_0-source;

  attrs = finalAttrs: rec {
    pname = "godot4${suffix}";
    inherit version;

    src = ./.;

    outputs = [
      "out"
      "man"
    ];
    separateDebugInfo = true;

    BUILD_NAME = "custom";

    preConfigure = lib.optionalString withMono ''
      # TODO: avoid pulling in dependencies of windows-only project
      dotnet sln modules/mono/editor/GodotTools/GodotTools.sln \
        remove modules/mono/editor/GodotTools/GodotTools.OpenVisualStudio/GodotTools.OpenVisualStudio.csproj

      dotnet restore modules/mono/glue/GodotSharp/GodotSharp.sln
      dotnet restore modules/mono/editor/GodotTools/GodotTools.sln
      dotnet restore modules/mono/editor/Godot.NET.Sdk/Godot.NET.Sdk.sln
    '';

    # From: https://github.com/godotengine/godot/blob/4.2.2-stable/SConstruct
    sconsFlags = mkSconsFlagsFromAttrSet {
      # Options from 'SConstruct'
      precision = withPrecision; # Floating-point precision level
      production = true; # Set defaults to build Godot for use in production
      platform = withPlatform;
      target = withTarget;
      debug_symbols = true;

      # Options from 'platform/linuxbsd/detect.py'
      dbus = withDbus; # Use D-Bus to handle screensaver and portal desktop settings
      fontconfig = withFontconfig; # Use fontconfig for system fonts support
      pulseaudio = withPulseaudio; # Use PulseAudio
      speechd = withSpeechd; # Use Speech Dispatcher for Text-to-Speech support
      touch = withTouch; # Enable touch events
      udev = withUdev; # Use udev for gamepad connection callbacks
      wayland = withWayland; # Compile with Wayland support
      x11 = withX11; # Compile with X11 support

      module_mono_enabled = withMono;

      linkflags = "-Wl,--build-id";
    };

    enableParallelBuilding = true;

    strictDeps = true;

    depsBuildBuild = lib.optionals (stdenv.buildPlatform != stdenv.hostPlatform) [
      buildPackages.stdenv.cc
      pkg-config
    ];

    buildInputs = lib.optionals withMono dotnet-sdk.packages;

    nativeBuildInputs =
      [
        autoPatchelfHook
        installShellFiles
        pkg-config
        scons
      ]
      ++ lib.optionals withWayland [ wayland-scanner ]
      ++ lib.optionals withMono [
        dotnet-sdk
        makeWrapper
      ];

    postBuild = lib.optionalString withMono ''
      echo "Generating Glue"
      if [[ ${withPrecision} == *double* ]]; then
          bin/godot.${withPlatform}.${withTarget}.${withPrecision}.${arch}.mono --headless --generate-mono-glue modules/mono/glue
      else
          bin/godot.${withPlatform}.${withTarget}.${arch}.mono --headless --generate-mono-glue modules/mono/glue
      fi
      echo "Building C#/.NET Assemblies"
      python modules/mono/build_scripts/build_assemblies.py --godot-output-dir bin --precision=${withPrecision}
    '';

    runtimeDependencies =
      [
        alsa-lib
        libGL
        vulkan-loader
      ]
      ++ lib.optionals withX11 [
        libX11
        libXcursor
        libXext
        libXfixes
        libXi
        libXinerama
        libxkbcommon
        libXrandr
        libXrender
      ]
      ++ lib.optionals withWayland [
        libdecor
        wayland
      ]
      ++ lib.optionals withDbus [
        dbus
        dbus.lib
      ]
      ++ lib.optionals withFontconfig [
        fontconfig
        fontconfig.lib
      ]
      ++ lib.optionals withPulseaudio [ libpulseaudio ]
      ++ lib.optionals withSpeechd [ speechd-minimal ]
      ++ lib.optionals withUdev [ udev ];

    installPhase =
      ''
        runHook preInstall

        mkdir -p "$out/bin"
        cp bin/godot.* $out/bin/godot4${suffix}

        installManPage misc/dist/linux/godot.6

        mkdir -p "$out"/share/{applications,icons/hicolor/scalable/apps}
        cp misc/dist/linux/org.godotengine.Godot.desktop "$out/share/applications/org.godotengine.Godot4${suffix}.desktop"
        substituteInPlace "$out/share/applications/org.godotengine.Godot4${suffix}.desktop" \
          --replace "Exec=godot" "Exec=$out/bin/godot4${suffix}" \
          --replace "Godot Engine" "Godot Engine 4"
        cp icon.svg "$out/share/icons/hicolor/scalable/apps/godot.svg"
        cp icon.png "$out/share/icons/godot.png"
      ''
      + lib.optionalString withMono ''
        cp -r bin/GodotSharp/ $out/bin/
        wrapProgram $out/bin/godot4${suffix} \
          --set DOTNET_ROOT ${dotnet-sdk} \
          --prefix PATH : "${
            lib.makeBinPath [
              dotnet-sdk
            ]
          }"
      ''
      + ''
        ls -a
        ln -s godot4${suffix} "$out"/bin/godot
        runHook post Install
      '';

    passthru = {
      tests =
        let
          pkg = finalAttrs.finalPackage;
          dottedVersion = lib.replaceStrings [ "-" ] [ "." ] version;
          exportedProject = stdenvNoCC.mkDerivation {
            name = "${pkg.name}-project-export";

            nativeBuildInputs = [
              pkg
              autoPatchelfHook
            ];

            runtimeDependencies = map lib.getLib [
              alsa-lib
              libGL
              libpulseaudio
              libX11
              libXcursor
              libXext
              libXi
              libXrandr
              udev
              vulkan-loader
            ];

            unpackPhase = ''
              runHook preUnpack

              mkdir test
              cd test
              touch project.godot

              cat >create-scene.gd <<'EOF'
              extends SceneTree

              func _initialize():
                var node = Node.new()
                var script = ResourceLoader.load("res://test.gd")
                print(script)
                node.set_script(script)
                var scene = PackedScene.new()
                var scenePath = "res://test.tscn"
                scene.pack(node)
                var x = ResourceSaver.save(scene, scenePath)
                ProjectSettings["application/run/main_scene"] = scenePath
                ProjectSettings.save()
                node.free()
                quit()
              EOF

              cat >test.gd <<'EOF'
              extends Node
              func _ready():
                print("Hello, World!")
                get_tree().quit()
              EOF

              cat >export_presets.cfg <<'EOF'
              [preset.0]
              name="build"
              platform="Linux"
              runnable=true
              export_filter="all_resources"
              include_filter=""
              exclude_filter=""
              [preset.0.options]
              __empty=""
              EOF

              runHook postUnpack
            '';

            buildPhase = ''
              runHook preBuild

              export HOME=$(mktemp -d)
              mkdir -p $HOME/.local/share/godot/export_templates
              ln -s "${pkg.export-templates-bin}" "$HOME/.local/share/godot/export_templates/${dottedVersion}"

              godot --headless -s create-scene.gd

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p "$out"/bin
              godot --headless --export-release build "$out"/bin/test

              runHook postInstall
            '';
          };
        in
        {
          version = testers.testVersion {
            package = pkg;
            version = dottedVersion;
          };

          project-runs = runCommand "${pkg.name}-project-runs" { } ''
            (
              set -eo pipefail
              HOME=$(mktemp -d)
              "${exportedProject}"/bin/test --headless | tail -n1 | (
                read output
                if [[ "$output" != "Hello, World!" ]]; then
                  echo "unexpected output: $output" >&2
                  exit 1
                fi
              )
              touch "$out"
            )
          '';
        };
    };

    requiredSystemFeatures = [
      # fixes: No space left on device
      "big-parallel"
    ];

    meta.mainProgram = "godot4${suffix}";
  };

in
stdenv.mkDerivation (
  if withMono then
    dotnetCorePackages.addNuGetDeps {
      inherit nugetDeps;
      overrideFetchAttrs = old: rec {
        runtimeIds = map (system: dotnetCorePackages.systemToDotnetRid system) old.meta.platforms;
        buildInputs =
          old.buildInputs
          ++ lib.concatLists (lib.attrValues (lib.getAttrs runtimeIds dotnet-sdk.targetPackages));
      };
    } attrs
  else
    attrs
)
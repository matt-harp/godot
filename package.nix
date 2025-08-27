{
  stdenv,
  lib,
  src,
  scons,
  pkg-config,
  perl,
  # Runtime dependencies
  alsa-lib,
  bzip2,
  dbus,
  fontconfig,
  freetype,
  glib,
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
  speechd-minimal,
  udev,
  vulkan-loader,
  wayland,
  wayland-scanner,
  zlib,
  autoPatchelfHook,
  # Feature flags
  withAlsa ? true,
  withDbus ? true,
  withFontconfig ? true,
  withPulseaudio ? true,
  withSpeechd ? true,
  withTouch ? true,
  withUdev ? true,
  withWayland ? true,
  withX11 ? true,
  withPrecision ? "double",
  buildTarget ? "editor"
}:

let
  arch = stdenv.hostPlatform.linuxArch;

  mkSconsFlagsFromAttrSet = lib.mapAttrsToList (
    k: v: if builtins.isString v then "${k}=${v}" else "${k}=${builtins.toJSON v}"
  );

  isEditor = buildTarget == "editor";
  isTemplate = lib.hasPrefix "template" buildTarget;

  binary = lib.concatStringsSep "." ([
    "godot"
    "linuxbsd"
    buildTarget
  ] ++ lib.optional (withPrecision != "single") withPrecision
    ++ [ arch ]);

  # Template naming for export templates directory
  templateName = if buildTarget == "template_release" then "linux_release.${arch}"
                 else if buildTarget == "template_debug" then "linux_debug.${arch}"
                 else null;

  vInfo = builtins.fromTOML (builtins.readFile ./version.py);
  version = "${toString vInfo.major}.${toString vInfo.minor}.${toString vInfo.patch}-${toString vInfo.status}";

in stdenv.mkDerivation rec {
  pname = "godot" + lib.optionalString isTemplate "-template" + lib.optionalString isEditor "-editor";
  inherit version;

  inherit src;

  outputs = [ "out" ];
  separateDebugInfo = true;

  BUILD_NAME = "custom";

  # Only apply patches if they exist in the repo
  patches = lib.optionals (builtins.pathExists "${src}/nix/patches") [
    # Add any custom patches here
  ];

  postPatch = ''
    # Allow scons to see NIX_CFLAGS_COMPILE
    perl -pi -e '{ $r += s:(env = Environment\(.*):\1\nenv["ENV"] = os.environ: } END { exit ($r != 1) }' SConstruct

    # Patch library paths for runtime loading
    substituteInPlace thirdparty/glad/egl.c \
      --replace-fail \
        'static const char *NAMES[] = {"libEGL.so.1", "libEGL.so"}' \
        'static const char *NAMES[] = {"${lib.getLib libGL}/lib/libEGL.so"}'

    substituteInPlace thirdparty/glad/gl.c \
      --replace-fail \
        'static const char *NAMES[] = {"libGLESv2.so.2", "libGLESv2.so"}' \
        'static const char *NAMES[] = {"${lib.getLib libGL}/lib/libGLESv2.so"}' \

    substituteInPlace thirdparty/glad/gl{,x}.c \
      --replace-fail \
        '"libGL.so.1"' \
        '"${lib.getLib libGL}/lib/libGL.so"'

    substituteInPlace thirdparty/volk/volk.c \
      --replace-fail \
        'dlopen("libvulkan.so.1"' \
        'dlopen("${lib.getLib vulkan-loader}/lib/libvulkan.so"'
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    scons
    pkg-config
    perl
  ] ++ lib.optionals withWayland [ wayland-scanner ];

  buildInputs = [
    libGL
    bzip2
    freetype
    zlib
  ] ++ lib.optional withAlsa alsa-lib
    ++ lib.optional (withX11 || withWayland) libxkbcommon
    ++ lib.optionals withX11 [
      libX11
      libXcursor
      libXext
      libXfixes
      libXi
      libXinerama
      libXrandr
      libXrender
    ]
    ++ lib.optionals withWayland [ wayland ]
    ++ lib.optional withDbus dbus
    ++ lib.optional withFontconfig fontconfig
    ++ lib.optional withPulseaudio libpulseaudio
    ++ lib.optionals withSpeechd [ speechd-minimal glib ]
    ++ lib.optional withUdev udev;

  runtimeDependencies = [
    libGL
    vulkan-loader
    bzip2
    freetype
    zlib
  ] ++ lib.optional withAlsa alsa-lib
    ++ lib.optional (withX11 || withWayland) libxkbcommon
    ++ lib.optionals withX11 [
      libX11
      libXcursor
      libXext
      libXfixes
      libXi
      libXinerama
      libXrandr
      libXrender
    ]
    ++ lib.optionals withWayland [ wayland ]
    ++ lib.optional withDbus dbus
    ++ lib.optional withFontconfig fontconfig
    ++ lib.optional withPulseaudio libpulseaudio
    ++ lib.optionals withSpeechd [ speechd-minimal glib ]
    ++ lib.optional withUdev udev;

  sconsFlags = mkSconsFlagsFromAttrSet {
    # Basic options
    precision = withPrecision;
    production = true;
    platform = "linuxbsd";
    target = buildTarget;
    debug_symbols = isEditor;

    # Feature flags
    alsa = withAlsa;
    dbus = withDbus; # Use D-Bus to handle screensaver and portal desktop settings
    fontconfig = withFontconfig; # Use fontconfig for system fonts support
    pulseaudio = withPulseaudio; # Use PulseAudio
    speechd = withSpeechd; # Use Speech Dispatcher for Text-to-Speech support
    touch = withTouch; # Enable touch events
    udev = withUdev; # Use udev for gamepad connection callbacks
    wayland = withWayland; # Compile with Wayland support
    x11 = withX11; # Compile with X11 support

    # No Mono
    module_mono_enabled = false;

    # Compiler flags
    ccflags = "-fno-strict-aliasing";
    linkflags = "-Wl,--build-id,-lbz2";

    use_sowrap = false;
  };

  enableParallelBuilding = true;
  strictDeps = true;

  buildPhase = ''
    runHook preBuild
    scons -j$NIX_BUILD_CORES ''${sconsFlags[@]}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,libexec}
    ls -R
    cp -r bin/* $out/libexec

	${if isEditor then ''
      # Create symlinks in bin
      cd $out/bin
      ln -s ../libexec/${binary} godot-editor
      ln -s godot-editor godot
      cd -
	'' else if isTemplate then ''
      # Install export templates
      templates="$out/share/godot/export_templates/${version}"
      mkdir -p "$templates"
      ln -s "$out/libexec/${binary}" "$templates/${templateName}"
	'' else ''
      # Generic binary installation
      cd $out/bin
      ln -s ../libexec/${binary} godot
      cd -
	''}

    runHook postInstall
  '';

  requiredSystemFeatures = [ "big-parallel" ];

  meta = with lib; {
    description = "Free and Open Source 2D and 3D game engine";
    homepage = "https://godotengine.org";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "i686-linux" ];
    maintainers = [ ];
    mainProgram = "godot";
  };
}

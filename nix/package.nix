{
  lib,
  stdenv,
  cmake,
  ninja,
  rsync,
  makeWrapper,
  qt6,
  python3,
  quickshell,
  matugen,
  grimblast,
  cliphist,
  wf-recorder,
  cava,
  brightnessctl,
  playerctl,
  libqalculate,
  imagemagick,
  mpv,
  tesseract,
  gperftools,
  kdePackages,
  qrencode,
  ffmpeg,
  ffmpegthumbnailer,
  jq,
  libnotify,
  xdg-utils,
  hyprpicker,
  wl-clipboard,
  wtype,
  papirus-folders,
  ddcutil,
  hypridle,
  swappy,
  sshfs,
  pulseaudio,
  easyeffects,
  extraWidgets ? [ ],
  src,
}:

let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      materialyoucolor
      pillow
      fonttools
      skia-pathops
    ]
  );

  runtimeDeps = [
    quickshell
    pythonEnv
    matugen
    grimblast
    cliphist
    wf-recorder
    cava
    brightnessctl
    playerctl
    libqalculate
    imagemagick
    mpv
    tesseract
    gperftools
    kdePackages.kdeconnect-kde
    qrencode
    ffmpeg
    ffmpegthumbnailer
    jq
    libnotify
    xdg-utils
    hyprpicker
    wl-clipboard
    wtype
    papirus-folders
    ddcutil
    hypridle
    swappy
    sshfs
    pulseaudio
    easyeffects
  ];
  widgetDecls =
    lib.concatMapStringsSep "\n" (
      w: "    readonly property Component c${w.name}: Component { ${w.name} { preview: true } }"
    ) extraWidgets
    + "\n    readonly property var catalog: root.allCatalog";
  widgetSection =
    "    readonly property var allCatalog: [\n"
    + "        { section: \"Custom\", icon: \"extension\", items: [\n"
    + lib.concatMapStringsSep "\n" (
      w:
      "            { label: \"${w.label}\", key: \"${w.key}\", comp: root.c${w.name}, show: \"${w.show}\" },"
    ) extraWidgets
    + "\n        ]},";
in

stdenv.mkDerivation {
  pname = "nebula";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [
    cmake
    ninja
    rsync
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtsvg
    qt6.qtmultimedia
    qt6.qtshadertools
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    for plugin in Nebula WfRecorder; do
      cmake -S "plugins/$plugin" -B ".build-$plugin" \
        -G Ninja -DCMAKE_BUILD_TYPE=Release
      cmake --build ".build-$plugin"
      cmake --install ".build-$plugin" --prefix "$out/lib/qt6/qml"
    done

    mkdir -p "$out/share/quickshell/nebula"
    rsync -a --exclude='.build-*' --exclude='.git*' ./ "$out/share/quickshell/nebula/"

    substituteInPlace "$out/share/quickshell/nebula/config/hypr/nebula/environment.lua" \
      --replace-fail \
        'hl.env("QML_IMPORT_PATH", home .. "/.local/lib/qt6/qml")' \
        'hl.env("QML_IMPORT_PATH", "'"$out"'/lib/qt6/qml:" .. home .. "/.local/lib/qt6/qml")' \
      --replace-fail \
        'hl.env("NEBULA_VENV",     home .. "/.local/state/quickshell/.venv")' \
        ""

    mkdir -p "$out/share/nebula"
    cp -r config/matugen "$out/share/nebula/matugen"
    cp assets/wallpapers/nebula-default.jpg "$out/share/nebula/"

    ${lib.optionalString (extraWidgets != [ ]) ''
      widgets_dir="$out/share/quickshell/nebula/modules/components/Widgets"
      ${lib.concatMapStringsSep "\n" (w: ''
        cp ${lib.escapeShellArg w.file} "$widgets_dir/${lib.escapeShellArg w.name}.qml"
      '') extraWidgets}
      substituteInPlace "$widgets_dir/WidgetCatalog.qml" \
        --replace-fail '    readonly property var catalog: root.allCatalog' \
          ${lib.escapeShellArg widgetDecls} \
        --replace-fail '    readonly property var allCatalog: [' \
          ${lib.escapeShellArg widgetSection}
    ''}

    makeWrapper ${pythonEnv}/bin/python "$out/bin/nebula" \
      --add-flags "-m nebula" \
      --prefix PYTHONPATH : "$out/share/quickshell/nebula/cli" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML_IMPORT_PATH : "$out/lib/qt6/qml" \
      --set NEBULA_PYTHON "${pythonEnv}/bin/python"

    runHook postInstall
  '';

  meta = {
    description = "Material You desktop shell for Hyprland, built with Quickshell";
    homepage = "https://github.com/iamSt3el/Nebula";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "nebula";
  };
}

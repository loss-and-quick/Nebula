{
  description = "Nebula — Material You desktop shell for Hyprland (Quickshell)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, quickshell }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                quickshell = quickshell.packages.${system}.default.override {
                  withModules = with prev.kdePackages; [
                    qqc2-desktop-style
                    kirigami
                  ];
                };
              })
            ];
          };
          pythonEnv = pkgs.python3.withPackages (ps: with ps; [
            materialyoucolor
            pillow
            fonttools
            skia-pathops
          ]);
          runtimeDeps = with pkgs; [
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
        in
        {
          default = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "nebula";
            version = "0.1.5";
            src = ./.;

            nativeBuildInputs = with pkgs; [
              cmake
              ninja
              rsync
              makeWrapper
              qt6.wrapQtAppsHook
            ];

            buildInputs = with pkgs.qt6; [
              qtbase
              qtdeclarative
              qtwayland
              qtsvg
              qtmultimedia
              qtshadertools
            ];

            dontConfigure = true;
            dontBuild = true;
            dontWrapQtApps = true;

            installPhase = ''
              runHook preInstall

              for plugin in Nebula WfRecorder; do
                cmake -S "plugins/$plugin" -B ".build-$plugin" -G Ninja -DCMAKE_BUILD_TYPE=Release
                cmake --build ".build-$plugin"
                cmake --install ".build-$plugin" --prefix "$out/lib/qt6/qml"
              done

              mkdir -p "$out/share/quickshell/nebula"
              rsync -a --exclude='.build-*' --exclude='.git*' ./ "$out/share/quickshell/nebula/"

              mkdir -p "$out/share/nebula"
              cp -r config/matugen "$out/share/nebula/matugen"
              cp assets/wallpapers/nebula-default.jpg "$out/share/nebula/"

              makeWrapper ${pythonEnv}/bin/python "$out/bin/nebula" \
                --add-flags "-m nebula" \
                --prefix PYTHONPATH : "$out/share/quickshell/nebula/cli" \
                --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}" \
                --prefix QML_IMPORT_PATH : "$out/lib/qt6/qml" \
                --set NEBULA_PYTHON "${pythonEnv}/bin/python"

              runHook postInstall
            '';

            meta = {
              description = "Material You desktop shell for Hyprland, built with Quickshell";
              homepage = "https://github.com/loss-and-quick/Nebula";
              license = pkgs.lib.licenses.gpl3Only;
              platforms = pkgs.lib.platforms.linux;
              mainProgram = "nebula";
            };
          });
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake
              ninja
              qt6.qtbase
              qt6.qtdeclarative
              (python3.withPackages (ps: with ps; [
                materialyoucolor
                pillow
                fonttools
                skia-pathops
              ]))
            ];
          };
        }
      );
    };
}

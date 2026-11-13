self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.nebula;
in
{
  options.programs.nebula = {
    enable = lib.mkEnableOption "Nebula desktop shell";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "Nebula package to use.";
    };
    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Nebula with the graphical session.";
    };
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Custom Nebula palette; an empty set leaves palette selection to Nebula.";
    };
    hyprland.enable = lib.mkEnableOption "Nebula Hyprland environment integration";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [ cfg.package ];
      xdg.configFile."matugen/templates".source = "${cfg.package}/share/nebula/matugen/templates";
      xdg.configFile."matugen/music_config.toml".source = "${cfg.package}/share/nebula/matugen/music_config.toml";
      home.file."wallpaper/nebula-default.jpg".source = "${cfg.package}/share/nebula/nebula-default.jpg";
      xdg.desktopEntries.nebula-setup = {
        name = "Nebula Setup";
        exec = "${cfg.package}/bin/nebula setup";
        icon = "${cfg.package}/share/quickshell/nebula/assets/nebula.png";
        categories = [ "Settings" ];
      };
    }
    (lib.mkIf (cfg.palette != { }) {
      xdg.configFile."nebula/colors.json".text = builtins.toJSON cfg.palette;
      xdg.configFile."nebula/defaults.json".text = builtins.toJSON { general.palette = "custom"; };
    })
    (lib.mkIf cfg.systemd.enable {
      systemd.user.services.nebula = {
        Unit = {
          Description = "Nebula desktop shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" "xdg-desktop-portal.service" ];
          Wants = [ "xdg-desktop-portal.service" ];
        };
        Service.ExecStart = "${cfg.package}/bin/nebula start --foreground";
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })
    (lib.mkIf cfg.hyprland.enable {
      wayland.windowManager.hyprland.settings.env = [
        "QML_IMPORT_PATH,${cfg.package}/lib/qt6/qml"
      ];
    })
  ]);
}

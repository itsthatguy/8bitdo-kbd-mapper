{
  description = "Key mapper for 8BitDo Retro Mechanical Keyboards";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        version = "0.0.0+${self.shortRev or "dirty"}";

        patchUdevRules = rulesFile:
          pkgs.runCommand (builtins.baseNameOf rulesFile) { } ''
            substitute ${rulesFile} $out \
              --replace-fail '/usr/bin/sh' '${pkgs.bash}/bin/sh'
          '';

        eightbdkbd = pkgs.python3Packages.buildPythonApplication {
          pname = "8bdkbd";
          inherit version;
          pyproject = true;

          src = self;

          env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

          build-system = with pkgs.python3Packages; [
            setuptools
            setuptools-scm
          ];

          dependencies = with pkgs.python3Packages; [
            pyusb
          ];

          # pyusb needs libusb1 at runtime
          makeWrapperArgs = [
            "--prefix" "LD_LIBRARY_PATH" ":" "${pkgs.lib.makeLibraryPath [ pkgs.libusb1 ]}"
          ];

          postInstall = ''
            install -Dm644 ${patchUdevRules ./50-8bitdo-kdb.rules} \
              $out/etc/udev/rules.d/50-8bitdo-kdb.rules
            install -Dm644 ${patchUdevRules ./50-8bitdo-108-key-kdb.rules} \
              $out/etc/udev/rules.d/50-8bitdo-108-key-kdb.rules
          '';

          meta = with pkgs.lib; {
            description = "Key mapper for 8BitDo's Retro Mechanical Keyboard";
            homepage = "https://github.com/goncalor/8bitdo-kbd-mapper/";
            license = licenses.gpl3Only;
            mainProgram = "8bdkbd";
          };
        };
      in
      {
        packages.default = eightbdkbd;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python3
            python3Packages.pyusb
            libusb1
          ];

          env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libusb1 ];
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.eightbdkbd;
          pkg = self.packages.${pkgs.system}.default;
        in
        {
          options.programs.eightbdkbd = {
            enable = lib.mkEnableOption "8BitDo Retro Mechanical Keyboard key mapper";
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ pkg ];
            services.udev.packages = [ pkg ];
          };
        };
    };
}

{
  inputs.nixpkgs.url = "github:dramforever/nixpkgs/rustcTarget-madness";

  outputs = { self, nixpkgs }:
    let eachSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
    in {
      legacyPackages = eachSystem (system:
        import nixpkgs {
          inherit system;
          crossSystem = {
            config = "mips64el-unknown-linux-gnuabi64";
            linux-kernel = {
              name = "lemote2f";
              target = "vmlinuz";
              baseConfig = "lemote2f_defconfig";
              autoModules = false;
            };
            gcc = {
              arch = "mips3";
              float = "hard";
              abi = "64";
            };
            rust = rec {
              platform = builtins.fromJSON (builtins.readFile "${./rust}/mips64el_mips3-unknown-linux-gnuabi64.json");
              rustcTargetSpec = "${./rust}/mips64el_mips3-unknown-linux-gnuabi64.json";
              cargoShortTarget = "mips64el_mips3-unknown-linux-gnuabi64";
              rustcTarget = cargoShortTarget;
            };
          };
          overlays = [
            self.overlays.overlay
            self.overlays.allow-modules-missing
          ];
        });

      overlays.overlay =
        final: prev: {
          linux_lemote2f =
            final.linuxManualConfig {
              inherit (final.linux) src modDirVersion;
              # https://github.com/NixOS/nixpkgs/pull/302802
              config = final.read-linux-config ./lemote2f_config;
              version = "${final.linux.version}-lemote2f";
              configfile = ./lemote2f_config;
              kernelPatches = [
                {
                  name = "ec_kb3310b";
                  patch = (final.fetchpatch {
                    url = "https://github.com/loongson-community/linux-2f/commit/08fda2d6be96684e4753e89fa54c33bb4553f621.patch";
                    hash = "sha256-CRKovOD/tDNptUSPhDnpp8INH6zXIoPmfU29PNYapA8=";
                  });
                }
                # {
                #   name = "yeeloong_laptop";
                #   patch = (final.fetchpatch {
                #     url = "https://github.com/loongson-community/linux-2f/commit/ad2584dbce931975c4a1219bf4ac8099aaf636c2.patch";
                #     hash = "sha256-GB8l1e5Yb3WIuiiiXorBsEKdDAjQdH7kvepkF+Rbjr8=";
                #   });
                # }
              ];
            };

          linuxPackages_lemote2f = final.linuxPackagesFor final.linux_lemote2f;

          read-linux-config = final.callPackage ./read-linux-config.nix {};

          # FIXME: libressl doesn't work on MIPS?
          netcat = if final.hostPlatform.isMips then final.netcat-gnu else prev.netcat;

          # https://github.com/NixOS/nixpkgs/pull/298001
          gnupg24 = if final.hostPlatform.isMips then prev.gnupg24.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [ final.buildPackages.libgpg-error ];
          }) else prev.gnupg24;

          # https://github.com/NixOS/nixpkgs/pull/298515
          # inherit (final.callPackage ./resholve {}) resholve;

          openssh =
            if final.hostPlatform.isMips
            then
              prev.openssh.overrideAttrs (old: {
                configureFlags = old.configureFlags ++ [ "--without-hardening" ];
              })
            else prev.openssh;

          pcre2 =
            if final.hostPlatform.isMips
            then
              prev.pcre2.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.buildPackages.autoreconfHook ];
              })
            else prev.pcre2;

          pmon-boot-cfg = final.callPackage ./pmon-boot-cfg {};
        };

      overlays.allow-modules-missing = self: super: {
        makeModulesClosure = args:
          super.callPackage "${super.path}/pkgs/build-support/kernel/modules-closure.nix" (args // { allowMissing = true; });
      };

      nixosConfigurations.sakimi = nixpkgs.lib.nixosSystem {
        system = "mips64el-linux";
        modules = [
          ./configuration.nix
          { nixpkgs.pkgs = self.legacyPackages."x86_64-linux"; }
        ];
      };

      packages.x86_64-linux.sakimi = self.nixosConfigurations.sakimi.config.system.build.toplevel;
    };
}

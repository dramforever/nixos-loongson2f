{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
              arch = "loongson2f";
              float = "hard";
              abi = "64";
            };
            emulator = pkgs:
              let
                mips64el = pkgs.lib.systems.elaborate pkgs.lib.systems.examples.mips64el-linux-gnuabi64;
                qemu-user = mips64el.emulator pkgs;
                qemu-user-wrapped = pkgs.writeShellScriptBin "qemu-mips64el-loongson2f" ''
                  exec "${qemu-user}" -cpu Loongson-2F "$@"
                '';
              in
                "${qemu-user-wrapped}/bin/qemu-mips64el-loongson2f";
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
                {
                  name = "yeeloong_laptop";
                  patch = (final.fetchpatch {
                    url = "https://github.com/loongson-community/linux-2f/commit/ad2584dbce931975c4a1219bf4ac8099aaf636c2.patch";
                    hash = "sha256-GB8l1e5Yb3WIuiiiXorBsEKdDAjQdH7kvepkF+Rbjr8=";
                  });
                }
              ];
            };

          linuxPackages_lemote2f = final.linuxPackagesFor final.linux_lemote2f;

          read-linux-config = final.callPackage ./read-linux-config.nix {};

          # FIXME: libressl doesn't work on MIPS?
          netcat = final.netcat-gnu;

          # https://github.com/NixOS/nixpkgs/pull/298001
          gnupg24 = prev.gnupg24.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [ final.buildPackages.libgpg-error ];
          });

          # https://github.com/NixOS/nixpkgs/pull/302859
          systemd =
            if final.hostPlatform.isMips
            then
              prev.systemd.overrideAttrs (old: {
                patches = old.patches ++ [
                  (final.fetchpatch {
                    url = "https://github.com/systemd/systemd/commit/8040fa55a1cbc34dede3205a902095ecd26c21e3.patch";
                    sha256 = "0c6z7bsndbkb8m130jnjpsl138sfv3q171726n5vkyl2n9ihnavk";
                  })
                ];
              })
            else prev.systemd;

          # https://github.com/NixOS/nixpkgs/pull/298515
          # inherit (final.callPackage ./resholve {}) resholve;

          openssh =
            if final.hostPlatform.isMips
            then
              prev.openssh.overrideAttrs (old: {
                configureFlags = old.configureFlags ++ [ "--without-hardening" ];
              })
            else prev.openssh;
        };

      overlays.allow-modules-missing = self: super: {
        makeModulesClosure = { kernel, firmware, rootModules, allowMissing ? true }:
          super.callPackage "${super.path}/pkgs/build-support/kernel/modules-closure.nix" {
            inherit kernel firmware rootModules;
            allowMissing = true;
          };
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

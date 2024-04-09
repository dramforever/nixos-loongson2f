{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.nixpkgs-pr-298515.url = "github:NixOS/nixpkgs/refs/pull/298515/head";

  outputs = { self, nixpkgs, nixpkgs-pr-298515 }:
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
              config = final.read-linux-config ./lemote2f_config;
              version = "${final.linux.version}-lemote2f";
              configfile = ./lemote2f_config;
            };

          linuxPackages_lemote2f = final.linuxPackagesFor final.linux_lemote2f;

          read-linux-config = final.callPackage ./read-linux-config.nix {};

          netcat = final.netcat-gnu;

          gnupg24 = prev.gnupg24.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [ final.buildPackages.libgpg-error ];
          });

          systemd = prev.systemd.overrideAttrs (old: {
            patches = old.patches ++ [
              (final.fetchpatch {
                name = "255-install-format-overflow.patch";
                url = "https://gitweb.gentoo.org/repo/gentoo.git/plain/sys-apps/systemd/files/255-install-format-overflow.patch?id=a25cf19d6f0dd41643c17cdfebbd87fde5e0e336";
                hash = "sha256-cysLY7KC+rmLNeKEE/DYTqMRqL7SSjBCRWuuZvU63zA=";
              })
            ];
          });

          inherit (final.callPackage (nixpkgs-pr-298515 + "/pkgs/development/misc/resholve") {}) resholve;
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

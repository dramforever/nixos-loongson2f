set -eo pipefail
shopt -s nullglob

usage() {
    echo "Usage: $0 <store-dir> <target> <root-dev> <default>" >&2
    exit 1
}

[ "$#" -ne 4 ] && usage

storeDir="$1"
target="$2"
rootDev="$3"
default="$4"

declare -A needed

copyFile() {
    needed["$2"]=1
    if [ ! -e "$2" ]; then
        echo "Copying $2" >&2
        cp -- "$1" "$2.tmp.$$"
        mv -- "$2.tmp.$$" "$2"
    fi
}

entry() {
    local system hash label kpath kname ipath iname args init
    system="$(realpath "$2")"
    if [[ "${system/#"$storeDir/"/}" =~ ([^-]+)-(.+) ]]; then
        hash="${BASH_REMATCH[1]::6}"
    else
        echo "Unrecognized generation name $i" >&2
        return
    fi
    label="$(cat "$system/nixos-version")"
    kpath="$(realpath "$system/kernel")"
    kname="${kpath/#"$storeDir/"/}"
    kname="${kname//"/"/-}"
    ipath="$(realpath "$system/initrd")"
    iname="${ipath/#"$storeDir/"/}"
    iname="${iname//"/"/-}"
    args="$(cat "$system/kernel-params")"
    init="$(realpath "$system/init")"

    copyFile "$kpath" "$target/nixos/$kname"
    copyFile "$ipath" "$target/nixos/$iname"
    cat <<END
title $1 ($hash) $label
    root $rootDev
    kernel nixos/$kname
    initrd nixos/$iname
    args $args init=$init

title $1 debug ($hash) $label
    root $rootDev
    kernel nixos/$kname
    initrd nixos/$iname
    args $args init=$init boot.shell_on_fail systemd.debug-shell=1

END
}

mkdir -p -- "$target/nixos"

entry default "$default" > "$target/nixos/boot.cfg.tmp.$$"

for i in /nix/var/nix/profiles/system-*-link; do
    if [[ "$(basename "$i")" =~ ^system-(.+)-link$ ]] ; then
        entry "${BASH_REMATCH[1]}" "$i" >> "$target/nixos/boot.cfg.tmp.$$"
    else
        echo "Unrecognized generation name $i" >&2
    fi
done

mv -- "$target/nixos/boot.cfg.tmp.$$" "$target/boot.cfg"

for f in "$target/nixos/"*; do
    if [ "${needed["$f"]}" != "1" ]; then
        echo "Removing unneeded $f"
        chmod -R +w -- "$f"
        rm -rf -- "$f"
    fi
done

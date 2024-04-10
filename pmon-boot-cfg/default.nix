{ coreutils, jq, writeShellApplication }:

writeShellApplication {
  name = "pmon-boot-cfg";
  runtimeInputs = [ coreutils jq ];
  text = builtins.readFile ./pmon-boot-cfg.sh;
}

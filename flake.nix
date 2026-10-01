{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: inputs.parts.lib.mkFlake { inherit inputs; } {
    systems = import inputs.systems;

    perSystem = { lib, pkgs, ... }: {

      packages.default = pkgs.yaziPlugins.mkYaziPlugin {
        pname = "lf.yazi";
        version = "0";
        src = lib.fileset.toSource {
          root = ./.;
          fileset = ./main.lua;
        };
        meta = {
          description = "Make yazi look like lf for no reason";
          homepage = "https://github.com/aleksanaa/lf.yazi";
          license = lib.licenses.mit;
          maintainers = with lib.maintainers; [ aleksana ];
        };
      };

      formatter = pkgs.writeShellScriptBin "formatter" ''
        ${lib.getExe pkgs.deno} fmt README.md
        ${lib.getExe pkgs.nixpkgs-fmt} .
        ${lib.getExe pkgs.stylua} main.lua
      '';
    };
  };
}

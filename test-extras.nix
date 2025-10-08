# Test configuration for extras functionality
{ pkgs ? import <nixpkgs> { } }:

let
  # Import the module
  lazyvimModule = import ./module.nix;

  # Create a minimal home-manager-like config
  testConfig = { config, lib, pkgs, ... }: {
    home.homeDirectory = "/tmp/test-home";
    programs.lazyvim = {
      enable = true;

      # Test enabling some extras
      extras = {
        lang.nix = {
          enable = true;
          config = ''
            opts = {
              servers = {
                nixd = {},
              },
            }
          '';
        };

        coding.yanky = {
          enable = true;
        };

        editor.dial.enable = true;
      };

      treesitterParsers = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        lua
        vim
      ];
    };
  };

  # Evaluate the module
  eval = pkgs.lib.evalModules {
    modules = [
      lazyvimModule
      testConfig
    ];
  };

in {
  inherit eval;

  # Test that extras are enabled
  enabledExtras = eval.config._module.args or "no-args";

  # Test that init.lua contains extras imports
  initLua = eval.config.xdg.configFile."nvim/init.lua".text or "no-init-lua";
}

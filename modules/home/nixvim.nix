{ pkgs, ... }:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        term_colors = true;
      };
    };

    globals = {
      mapleader = " ";
      maplocalleader = "\\";
    };

    opts = {
      number = true;
      relativenumber = true;
      
      # Tabs
      tabstop = 2;
      softtabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      smartindent = true;

      # Search
      ignorecase = true;
      smartcase = true;

      # UI
      cursorline = true;
      termguicolors = true;
      scrolloff = 8;
      
      # System
      mouse = "a";
      clipboard = "unnamedplus";
      undofile = true;
    };

    plugins = {
      lualine.enable = true;
      bufferline.enable = true;
      web-devicons.enable = true;
      which-key.enable = true;

      # Treesitter
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      # File Explorer
      neo-tree = {
        enable = true;
        closeIfLastWindow = true;
      };

      # Fuzzy Finder
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
        };
      };
      
      # LSP & Completion
      lsp = {
        enable = true;
        servers = {
          nixd.enable = true; # Nix
          lua_ls.enable = true; # Lua
          pyright.enable = true; # Python
          bashls.enable = true; # Bash
          html.enable = true; # HTML
          cssls.enable = true; # CSS
          ts_ls.enable = true; # TS/JS
        };
      };
      
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
           sources = [
             { name = "nvim_lsp"; }
             { name = "path"; }
             { name = "buffer"; }
           ];
           mapping = {
             "<C-Space>" = "cmp.mapping.complete()";
             "<CR>" = "cmp.mapping.confirm({ select = true })";
             "<Tab>" = "cmp.mapping.select_next_item()";
             "<S-Tab>" = "cmp.mapping.select_prev_item()";
           };
        };
      };
      cmp-nvim-lsp.enable = true;
      cmp-path.enable = true;
      cmp-buffer.enable = true;

      # UI Improvements
      notify = {
        enable = true;
        settings.background_colour = "#000000";
      };

      noice = {
        enable = true;
        settings = {
          notify.enabled = true;
          presets = {
            bottom_search = true;
            command_palette = true;
            long_message_to_split = true;
            inc_rename = false;
            lsp_doc_border = false;
          };
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Toggle Explorer";
      }
      {
        mode = "n";
        key = "<C-s>";
        action = "<cmd>w<cr>";
        options.desc = "Save File";
      }
    ];
  };
}

# lf.yazi

Make yazi look like [lf](https://github.com/gokcehan/lf) for no reason.

<img width="2495" height="1600" alt="image" src="https://github.com/user-attachments/assets/fd05f9b7-e8ae-4f0c-af4d-0dfed695a5af" />

> Can you tell which one is yazi? At least [@sxyazi](https://github.com/sxyazi/) cannot...

## Installation

Copy or clone this directory to `~/.config/yazi/plugins/lf.yazi`, then add this
to `~/.config/yazi/init.lua`:

```lua
require("lf"):setup()
```

To change the pane ratios (like lf's `set ratios`):

```lua
require("lf"):setup { ratio = { 1, 3, 4 } }
```

## Nix

### Try it

Run yazi with only this plugin loaded:

```sh
nix run github:aleksanaa/lf.yazi
```

### Home Manager

Add this repository as a flake input named `lf-yazi`, and:

```nix
programs.yazi.plugins.lf = {
  package = inputs.lf-yazi.packages.${pkgs.stdenv.hostPlatform.system}.default;
  setup = true;
  # settings.ratio = [ 1 3 4 ];
};
```

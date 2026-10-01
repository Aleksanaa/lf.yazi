# lf.yazi

Make yazi look like [lf](https://github.com/gokcehan/lf) for no reason.

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

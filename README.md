exenv.el
========

use exenv to manage your Elixir versions within Emacs

Installation
------------

```lisp
(add-to-list 'load-path (expand-file-name "/path/to/exenv.el/"))
(require 'exenv)
(global-exenv-mode)
```

Usage
-----

* `global-exenv-mode` activate / deactivate exenv.el (The current Elixir version is shown in the modeline)
* `exenv-use-global` will activate your global elixir
* `exenv-use` allows you to choose what elixir version you want to use
* `exenv-use-corresponding` searches for .elixir-version and activates
  the corresponding elixir

Configuration
-------------

**exenv installation directory**
By default exenv.el assumes that you installed exenv into
`~/.exenv`. If you use a different installation location you can
customize exenv.el to search in the right place:

```lisp
(setq exenv-installation-dir "/usr/local/exenv")
```

*IMPORTANT:*: Currently you need to set this variable before you load exenv.el

**the modeline**
exenv.el will show you the active elixir in the modeline. If you don't
like this feature you can disable it:

```lisp
(setq exenv-show-active-elixir-in-modeline nil)
```

The default modeline representation is the elixir version (colored red) in square
brackets. You can change the format by customizing the variable:

```lisp
;; this will remove the colors
(setq exenv-modeline-function 'exenv--modeline-plain)
```

You can also define your own function to format the elixir version as you like.

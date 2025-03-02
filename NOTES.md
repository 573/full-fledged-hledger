* https://gist.github.com/573/2634dfe8d1e47ca00baa779a4879bd50
* https://gist.github.com/573/2e50a2d8a74e8927760a4a132ff8a343
* https://gist.github.com/573/737c5bb4d06f6b26107ed84612a0d5fa
* TODO doing as here: https://github.com/drupol/ipc2023/blob/79516f3/flake.nix#L124

Very WIP I can (commit 7e7e67c):

* `nix develop`
* `cd 13-tax-returns/`
* `export.hs` (the derivation)

repl:
```
>nix-repl> :lf flake:nixpkgs
Added 15 variables.
nix-repl> cleanFilter = lib.sources.cleanSourceWith { src = ./.; filter = pathstring: type: (type != "directory" || builtins.baseNameOf pathstring != ".git") && !lib.hasSuffix ".nix" pathstring && !lib.hasPrefix "." (builtins.baseNameOf pathstring); }
nix-repl> docs  = lib.fileset.toList (lib.fileset.intersection (lib.fileset.fromSource cleanFilter) (lib.fileset.fileFilter (file: !lib.hasPrefix "." file.name) ./.))
nix-repl> builtins.baseNameOf (lib.lists.last docs)
nix-repl> lib.fileset.trace (lib.fileset.fromSource cleanFilter)
nix-repl> docs  = lib.fileset.toList (lib.fileset.fileFilter (file: !lib.hasPrefix "." file.name) ./.)
```

(https://github.com/NixOS/nixpkgs/issues/271307)

````
WIP (ffd8f8a)
nix develop --builders ''
cd 03-getting-full-history/
03-getting-full-history-export.sh --base $(pwd)
````

My dead-end failed refactoring was 92a0097


I can now 

```
# commit 6f1e9b2
cd 16-fetching-prices
16-fetching-prices-export.sh --base `pwd`
```


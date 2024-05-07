/*
 - https://www.zombiezen.com/blog/2023/12/bundling-scripts-nix/
 - https://determinate.systems/posts/nix-run/
 - https://nixos-and-flakes.thiscute.world/other-usage-of-flakes/outputs
 - https://community.flake.parts/process-compose-flake
 - https://discourse.nixos.org/t/run-qt-app-from-flake/27517
 - https://litchipi.github.io/nix/2023/01/12/build-jekyll-blog-with-nix.html
 - https://github.com/srid/tailwind-haskell/blob/master/flake.nix
 - https://nixos.asia/en/nixify-haskell-nixpkgs
 - https://tonyfinn.com/blog/nix-from-first-principles-flake-edition/nix-9-runnable-flakes/
 - https://nixos.asia/en/writeShellApplication
 - https://discourse.nixos.org/t/basic-flake-run-existing-python-bash-script/19886
 - https://discourse.nixos.org/t/accessing-flake-outputs-in-the-flake-itself/14662
        - https://ertt.ca/nix/shell-scripts/
 - https://nixos.wiki/wiki/Shell_Scripts
 - https://discourse.nixos.org/t/move-script-from-flake-into-its-own-file/21158
# see https://shakebuild.com/commandline and https://github.com/ndmitchell/shake/issues/824
*/
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e89cf1c932006531f454de7d652163a9a5c86668";
    flake-utils.url = "github:numtide/flake-utils";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    systems,
    treefmt-nix,
    ...
  } @ inputs: let
    inherit (nixpkgs.lib) listToAttrs;

    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (
        system:
          f nixpkgs.legacyPackages.${system}
      );

    treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in {
    packages = eachSystem (pkgs: let
      mkPathEntry = {
        name,
        folder ? "",
        scriptName,
      }:
        pkgs.writeScriptBin scriptName (builtins.readFile "${self.packages.${pkgs.system}.default}/${name}/${folder}/${scriptName}");
    in {
      default = pkgs.callPackage ./package.nix {};
      helpers = pkgs.stdenvNoCC.mkDerivation rec {};
      in2csv = mkPathEntry {
        name = "11-sorting-unknowns";
        folder = "import/lloyds";
        scriptName = "in2csv";
      };

      csv2journal = mkPathEntry {
        name = "11-sorting-unknowns";
        folder = "import/lloyds";
        scriptName = "csv2journal";
      };
      investments = mkPathEntry {
        folder = "export";
        name = "11-sorting-unknowns";
        scriptName = "investments.sh";
      };
      mortgage_interest = mkPathEntry {
        folder = "export";
        name = "11-sorting-unknowns";
        scriptName = "mortgage_interest.sh";
      };
      matching_rules = mkPathEntry {
        folder = "export";
        name = "15-manual-lots";
        scriptName = "matching_rules.py";
      };
      pension = mkPathEntry {
        folder = "export";
        name = "15-manual-lots";
        scriptName = "pension.sh";
      };
      stock-options = mkPathEntry {
        folder = "export";
        name = "15-manual-lots";
        scriptName = "stock-options.sh";
      };
      tax_return = mkPathEntry {
        folder = "export";
        name = "13-tax-returns";
        scriptName = "tax_return.sh";
      };
      export-hs = mkPathEntry { # FIXME prob better wrap here with export.sh as one derivation
        folder = "export";
        name = "13-tax-returns";
        scriptName = "export.hs";
      };
      export = mkPathEntry {
        folder = "";
        name = "13-tax-returns";
        scriptName = "export.sh";
      };
      resolve = mkPathEntry {
        folder = "";
        name = "13-tax-returns";
        scriptName = "resolve.sh";
      };
    });

    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell (with pkgs; {
        buildInputs = [
          # Add development dependencies here
          patchutils
          gawk
          skim
          csvtool
          ripgrep
          python3
          parallel
          hledger
          hledger-interest
          (haskell.packages.ghc946.ghcWithHoogle (pset: with pset; [shake]))
          self.packages.${pkgs.system}.in2csv
          self.packages.${pkgs.system}.csv2journal
          self.packages.${pkgs.system}.investments
          self.packages.${pkgs.system}.mortgage_interest
          self.packages.${pkgs.system}.tax_return
          self.packages.${pkgs.system}.export
          self.packages.${pkgs.system}.resolve
          self.packages.${pkgs.system}.export-hs
          self.packages.${pkgs.system}.matching_rules
          self.packages.${pkgs.system}.pension
          self.packages.${pkgs.system}.stock-options
        ];
      });
    });

    # Run `nix fmt [FILE_OR_DIR]...` to execute formatters configured in treefmt.nix.
    formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

    checks = eachSystem (pkgs: {
      # Throws an error if any of the source files are not correctly formatted
      # when you run `nix flake check --print-build-logs`. Useful for CI
      formatting = treefmtEval.${pkgs.system}.config.build.check self;
    });
  };
}

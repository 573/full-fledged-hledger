{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/e1ee359d16a1886f0771cc433a00827da98d861c";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
	inherit (nixpkgs.lib) listToAttrs;
	mkPathEntry = { folder ? "", name, scriptName }:  pkgs.writeScriptBin scriptName (builtins.readFile "${self.packages.${system}.default}/${name}/${folder}/${scriptName}");
	my-investments = name: [ (mkPathEntry { folder = "export"; inherit name; scriptName = "investments.sh"; }) ];
	my-mortgage-interest = name: [ (mkPathEntry { folder = "export"; inherit name; scriptName = "mortgage_interest.sh"; }) ] ++ (my-investments name);
	my-tax-return = name: [ (mkPathEntry { folder = "export"; inherit name; scriptName = "tax_return.sh"; }) ] ++ (my-mortgage-interest name);
	my-budget = name: [ (mkPathEntry { folder = "export"; inherit name; scriptName = "budget.sh"; }) ] ++ (my-tax-return name);
	mkExportMortgage = name: mkProgram { inherit name; scriptName = "export.sh"; pathEntries = (my-mortgage-interest name); };
	mkResolveMortgage = name: mkProgram { inherit name; scriptName = "resolve.sh"; pathEntries = (my-mortgage-interest name); };
	mkExportTaxReturn = name: mkProgram { inherit name; scriptName = "export.sh"; pathEntries = (my-tax-return name); };
	mkResolveTaxReturn = name: mkProgram { inherit name; scriptName = "resolve.sh"; pathEntries = (my-tax-return name); };
	mkProgram = { name, scriptName, pathEntries ? [] }: pkgs.symlinkJoin rec {
		my-buildInputs = with pkgs; [ patchutils gawk skim csvtool ripgrep python3 parallel hledger hledger-interest (haskell.packages.ghc946.ghcWithHoogle (pset: with pset; [ shake ])) ];
	        my-src = builtins.readFile "${self.packages.${system}.default}/${name}/${scriptName}";
		my-hs = mkPathEntry { folder = "export"; inherit name; scriptName = "export.hs"; }; # (pkgs.writeScriptBin "export.hs" (builtins.readFile "${self.packages.${system}.default}/${name}/export/export.hs")).overrideAttrs(old: {
		#  buildCommand = "${old.buildCommand}\n mkdir -p $out/export\n mv * $out/export/export.hs";
		#})
		my-incsv = mkPathEntry { folder = "import/lloyds"; inherit name; scriptName = "in2csv"; };
                my-csvjournal = mkPathEntry { folder = "import/lloyds"; inherit name; scriptName = "/csv2journal"; };

		my-script = pkgs.writeScriptBin name (builtins.readFile "${self.packages.${system}.default}/${name}/${scriptName}");

		  inherit name;
		  paths = [ my-script my-hs my-incsv my-csvjournal ] ++ pathEntries ++ my-buildInputs;
		  # ([ my-script my-hs my-incsv my-csvjournal my-investments my-mortgage-interest my-tax-return my-budget ] ++ pathEntries);# ++ my-buildInputs;
		  buildInputs = [ pkgs.makeWrapper ];
		  postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
	} + "/bin/${name}";
      in
      {
        packages = {
	  default = pkgs.callPackage ./package.nix {};
        };
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
	      # TODO https://github.com/adept/full-fledged-hledger/blob/master/11-sorting-unknowns/export/investments.sh
	      # TODO https://github.com/adept/full-fledged-hledger/blob/master/11-sorting-unknowns/export/mortgage_interest.sh
	      # TODO https://github.com/adept/full-fledged-hledger/blob/master/14-speeding-up/export/tax_return.sh
	      # TODO https://github.com/adept/full-fledged-hledger/blob/master/14-speeding-up/export/matching_rules.py
	      # TODO https://github.com/adept/full-fledged-hledger/blob/master/15-manual-lots/export/pension.sh
	      # TODO https://github.com/adept/full-fledged-hledger/blob/master/15-manual-lots/export/stock-options.sh

	      /*
	      01-getting-started/
02-getting-data-in/
03-getting-full-history/
04-adding-more-accounts/
05-creating-csv-import-rules/
06-maintaining-lots-of-csv-rules/
07-investments-easy-approach/
08-mortgage/
09-remortgage/
10-foreign-currency/
11-sorting-unknowns/
12-file-specific-rules/
13-tax-returns/
14-speeding-up/
15-budgeting/
	      */
        apps = listToAttrs [
          ({
              name = "03-getting-full-history-export";	
              value = {
                program = mkProgram { name = "03-getting-full-history"; scriptName = "export.sh"; };
		type = "app";
              };
          })
	  (rec {
              name = "07-investments-easy-approach-export";	
              value = {
                program = mkProgram { name = "07-investments-easy-approach"; scriptName = "export.sh"; pathEntries = (my-investments name); };
		type = "app";
              };
          })
          (rec {
              name = "08-mortgage-export";	
              value = {
                program = (mkExportMortgage "08-mortgage");
		type = "app";
              };
          })
          (rec {
              name = "09-remortgage-export";	
              value = {
                program = mkExportMortgage "09-remortgage";
		type = "app";
              };
          })
	  (rec {
              name = "10-foreign-currency-export";	
              value = {
                program = mkExportMortgage "10-foreign-currency";
		type = "app";
              };
          })
	  (rec {
	    name = "11-sorting-unknowns-resolve";
	    value = {
	      program = mkResolveMortgage "11-sorting-unknowns";
	      type = "app";
	    };
	  })
          (rec {
              name = "11-sorting-unknowns-export";	
              value = {
                program = mkExportMortgage "11-sorting-unknowns";
		type = "app";
              };
          })
          (rec {
	    name = "12-file-specific-rules-resolve";
	    value = {
	      program = mkResolveMortgage "12-file-specific-rules";
	      type = "app";
	    };
	  })
	  (rec {
            name = "12-file-specific-rules-export";
	    value = {
                program = mkExportMortgage "12-file-specific-rules";
		type = "app";
              };
          })
          (rec {
	    name = "13-tax-returns-resolve";
	    value = {
	      program = mkResolveTaxReturn "13-tax-returns";
	      type = "app";
	    };
	  })
          (rec {
            name = "13-tax-returns-export";
	    value = {
                program = mkExportTaxReturn "13-tax-returns";
		type = "app";
              };
          })
          (rec {
	    name = "14-speeding-up-resolve";
	    value = {
	      program = mkResolveTaxReturn "14-speeding-up";
	      type = "app";
	    };
	  })
          (rec {
            name = "14-speeding-up-export";
	    value = {
                program = mkExportTaxReturn "14-speeding-up";
		type = "app";
              };
          })
          /*(rec {
	    name = "15-budgeting-resolve";
	    value = {
	      program = mkProgram "15-budgeting" "resolve.sh" (my-budget name);
	      type = "app";
	    };
	  })
          (rec {
            name = "15-budgeting-export";
	    value = {
                program = mkProgram "15-budgeting" "export.sh" (my-budget name);
		type = "app";
              };
          })*/
	];
      }
    )
    // {
      nixosModules.default = _: { };
    };
}


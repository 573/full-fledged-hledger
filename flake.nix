{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/09a89a1fe81124d2bb104b97d0c734ba60a2f0eb";
    flake-utils.url = "github:numtide/flake-utils";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pricehist = {
      url = "github:chrisberkhout/pricehist";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    treefmt-nix,
    ...
  } @ inputs: let
    inherit (nixpkgs.lib) optionalDrvAttr listToAttrs filterAttrs hasPrefix pathIsRegularFile pathIsDirectory optionalString makeSearchPath;

    inherit (nixpkgs) lib;

    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (
        system:
          f nixpkgs.legacyPackages.${system}
      );

    documentNames = builtins.attrNames (filterAttrs (k: v: (v == "directory" && k != "diffs" && k != "z98-budgeting" && !hasPrefix "." k)) (builtins.readDir ./.));

    cleanFilter = lib.sources.cleanSourceWith {
      src = ./.;
      filter = pathstring: type: !lib.hasPrefix "." (builtins.baseNameOf pathstring);
    };

    txtNames = lib.fileset.toList (lib.fileset.intersection (lib.fileset.fromSource cleanFilter) (lib.fileset.fileFilter (file: file.hasExt "txt" && !lib.hasPrefix "." file.name) ./.));

    csvNames = lib.fileset.toList (lib.fileset.intersection (lib.fileset.fromSource cleanFilter) (lib.fileset.fileFilter (file: file.hasExt "csv" && !lib.hasPrefix "." file.name) ./.));

    scriptNames = lib.fileset.toList (lib.fileset.intersection (lib.fileset.fromSource cleanFilter) (lib.fileset.fileFilter (file: (file.hasExt "sh" || file.hasExt "py" || lib.lists.length (lib.strings.splitString "." file.name) == 1) && !lib.hasPrefix "." file.name) ./.));

    treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
  in {
    packages = eachSystem (pkgs: {
      default = pkgs.callPackage ./package.nix {};
    });

    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell (with pkgs; {
        buildInputs = let
          folderDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                # export.hs seems
                # (https://github.com/adept/full-fledged-hledger/blob/e61fb70/01-getting-started/export/export.hs#L88)
                # to have flag --base (i. e. `script.sh --base .`)
                # (see https://hackage.haskell.org/package/shake-0.19.8/docs/Development-Shake.html#v:shakeArgsWith)
                # although IDK if shake is needed for it, I use runhaskell
                "folder-${i}" = stdenv.mkDerivation {
                  pname = "${i}";
                  version = "2024";
                  src = "${self.packages.${pkgs.system}.default}/${i}";
                  installPhase = ''
                                  mkdir $out
                                  cp -r * $out/
                    find $out/ -type f -name "*.sh" -exec chmod +x {} \;
                  '';
                  meta.description = "folder ${i}";
                };
              })
            {}
            documentNames;

          scriptDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "export-sh-${i}" = let
                  mkPathEntry = {
                    name,
                    folder ? "",
                    scriptName,
                  }:
                  # not just ${self}, but processed by package.nixpkgs
                    pkgs.writeTextFile {
                      name = scriptName;
                      executable = true;
                      destination = "/${folder}/${scriptName}";
                      text = builtins.readFile "${self.packages.${pkgs.system}.default}/${name}/${folder}/${scriptName}";
                    };

                  export =
                    (pkgs.writeTextFile {
                      name = "${i}-export.sh";
                      executable = true;
                      destination = "/bin/${i}-export.sh";
                      text = builtins.readFile "${folderDrvs."folder-${i}"}/export.sh";
                    })
                    .overrideAttrs {postInstall = "chmod +x $out/bin/${i}-export.sh";};

                  export-hs = mkPathEntry {
                    name = "${i}";
                    folder = "export";
                    scriptName = "export.hs";
                  };

                  in2csv = mkPathEntry {
                    name = "${i}";
                    folder = "import/lloyds";
                    scriptName = "in2csv";
                  };

                  csv2journal = mkPathEntry {
                    name = "${i}";
                    folder = "import/lloyds";
                    scriptName = "csv2journal";
                  };

                  demo-wrapped-better = let
                    exportFldr = pkgs.symlinkJoin {
                      name = "example";
                      paths = [
                        folderDrvs."folder-${i}"
                        export-hs
                      ];
                    };
                    importFldr = pkgs.symlinkJoin {
                      name = "example2";
                      paths = [in2csv csv2journal];
                    };

                    importSearchPath = optionalString (pathIsDirectory "${self}/${i}/import") ((makeSearchPath "import/lloyds" ["${importFldr}"]) + ":");
                    exportSearchPath = (makeSearchPath "export" ["${exportFldr}"]) + ":${folderDrvs."folder-${i}"}";
                  in
                    # FIXME problem shebang already there: https://discourse.nixos.org/t/can-i-package-a-shell-script-without-rewriting-it/8420/8
                    pkgs.runCommandLocal "demo-wrapped-better-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper export];
                    } ''
                      makeWrapper "${export}/bin/${i}-export.sh" "$out/bin/${i}-export.sh" --prefix PATH : ${importSearchPath}${exportSearchPath}
                    '';
                in
                  demo-wrapped-better;
              })
            {}
            documentNames;

          investmentsDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "investments-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  investments = pkgs.writeTextFile {
                    name = "${i}-investments.sh";
                    executable = true;
                    destination = "/bin/investments.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/investments.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper investments];
                    } ''
                      makeWrapper "${investments}/bin/investments.sh" "$out/bin/${i}-investments.sh"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh") wrapped;
              })
            {}
            documentNames;

          mortgageInterestDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "mortgage_interest-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  mortgageInterest = pkgs.writeTextFile {
                    name = "${i}-mortgage_interest.sh";
                    executable = true;
                    destination = "/bin/mortgage_interest.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/mortgage_interest.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper mortgageInterest];
                    } ''
                      makeWrapper "${mortgageInterest}/bin/mortgage_interest.sh" "$out/bin/${i}-mortgage_interest.sh"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/mortgage_interest.sh") wrapped;
              })
            {}
            documentNames;

          taxReturnDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "tax_return-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  taxReturn = pkgs.writeTextFile {
                    name = "${i}-tax_return.sh";
                    executable = true;
                    destination = "/bin/tax_return.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/tax_return.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper taxReturn];
                    } ''
                      makeWrapper "${taxReturn}/bin/tax_return.sh" "$out/bin/${i}-tax_return.sh"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/tax_return.sh") wrapped;
              })
            {}
            documentNames;
          matchingRulesDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "matching_rules-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  matchingRules = pkgs.writeTextFile {
                    name = "${i}-matching_rules.py";
                    executable = true;
                    destination = "/bin/matching_rules.py";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/matching_rules.py";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper matchingRules];
                    } ''
                      makeWrapper "${matchingRules}/bin/matching_rules.py" "$out/bin/${i}-matching_rules.py"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/matching_rules.py") wrapped;
              })
            {}
            documentNames;
          pensionDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "pension-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  pension = pkgs.writeTextFile {
                    name = "${i}-pension.sh";
                    executable = true;
                    destination = "/bin/pension.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/pension.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper pension];
                    } ''
                      makeWrapper "${pension}/bin/pension.sh" "$out/bin/${i}-pension.sh"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/pension.sh") wrapped;
              })
            {}
            documentNames;

          stockOptionsDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "stock-options-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  stockOptions = pkgs.writeTextFile {
                    name = "${i}-stock-options.sh";
                    executable = true;
                    destination = "/bin/stock-options.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/stock-options.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper stockOptions];
                    } ''
                      makeWrapper "${stockOptions}/bin/stock-options.sh" "$out/bin/${i}-stock-options.sh" --prefix PATH : "${self}/${i}/import"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/stock-options.sh") wrapped;
              })
            {}
            documentNames;
          priceDatesDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "price_dates-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  priceDates = pkgs.writeTextFile {
                    name = "${i}-price_dates.sh";
                    executable = true;
                    destination = "/bin/price_dates.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/price_dates.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper priceDates];
                    } ''
                      makeWrapper "${priceDates}/bin/price_dates.sh" "$out/bin/${i}-price_dates.sh"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/price_dates.sh") wrapped;
              })
            {}
            documentNames;
          pricesDrvs =
            nixpkgs.lib.foldl'
            (a: i:
              a
              // {
                "prices-${i}" = let
                  #optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/investments.sh")
                  prices = pkgs.writeTextFile {
                    name = "${i}-prices.sh";
                    executable = true;
                    destination = "/bin/prices.sh";
                    text = builtins.readFile "${folderDrvs."folder-${i}"}/export/prices.sh";
                  };

                  wrapped =
                    pkgs.runCommandLocal "wrapped-${i}" {
                      nativeBuildInputs = [pkgs.makeWrapper prices];
                    } ''
                      makeWrapper "${prices}/bin/prices.sh" "$out/bin/${i}-prices.sh"
                    '';
                in
                  optionalDrvAttr (pathIsRegularFile "${self}/${i}/export/prices.sh") wrapped;
              })
            {}
            documentNames;
        in
          (lib.attrValues investmentsDrvs)
          ++ (lib.attrValues pricesDrvs)
          ++ (lib.attrValues priceDatesDrvs)
          ++ (lib.attrValues pensionDrvs)
          ++ (lib.attrValues stockOptionsDrvs)
          ++ (lib.attrValues matchingRulesDrvs)
          ++ (lib.attrValues taxReturnDrvs)
          ++ (lib.attrValues mortgageInterestDrvs)
          ++ (lib.attrValues scriptDrvs)
          ++ [
            # Add development dependencies here
            patchutils
            gawk
            skim
            csvtool
            ripgrep
            python3
	    (pricehist.overrideAttrs (old: {
	      src = inputs.pricehist;
	    }))
            parallel
            hledger
            hledger-interest
            (haskell.packages.ghc946.ghcWithHoogle (pset: with pset; [shake]))
          ];
        /*
        self.packages.${pkgs.system}.in2csv
        */
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

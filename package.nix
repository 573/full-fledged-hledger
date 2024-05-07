{
  stdenvNoCC,
  runCommand,
  makeWrapper,
  hledger,
  stack,
  python3,
  parallel,
  skim,
  csvtool,
  ripgrep,
  hledger-interest,
  haskell,
  lib,
  ...
} @ args:
#with pkgs;
#with pkgs.lib;
let
  # Create a patch against src based on changes applied in patchCommands
  mkPatch = {
    name,
    src,
    patchCommands,
  }:
    runCommand "${name}-full-fledged-hledger.patch" {inherit src;} ''
      source $stdenv/setup
      unpackPhase

      orig=$sourceRoot
      new=$sourceRoot-modded
      cp -r $orig/. $new/

      pushd $new >/dev/null
      ${patchCommands}
      popd >/dev/null

      diff -Naur $orig $new > $out || true
    '';
in
  stdenvNoCC.mkDerivation rec {
    name = "full-fledged-hledger";

    nativeBuildInputs = [makeWrapper];
    propagatedBuildInputs = [hledger stack python3 parallel];

    #  buildInputs = [
    #    stack
    #    hledger
    #  ];

    src = with builtins;
      filterSource
      (path: _:
        !elem (baseNameOf path) [".git" "result" "bin" "_build" "_build_ci" "_build_vo" "nix" ".stack"])
      ./.;

    patches = [
      (mkPatch {
        name = "use-runhaskell";
        inherit src;
        patchCommands = ''
            substituteInPlace {01-getting-started,02-getting-data-in,03-getting-full-history,04-adding-more-accounts,05-creating-csv-import-rules,06-maintaining-lots-of-csv-rules,07-investments-easy-approach,08-mortgage,09-remortgage,10-foreign-currency,11-sorting-unknowns,12-file-specific-rules,13-tax-returns,14-speeding-up,15-manual-lots}/export/export.hs \
          --replace 'env stack' 'env runhaskell' \
          --replace '"./in2csv"' '"in2csv"' \
          --replace '"./csv2journal"' '"csv2journal"' \
          --replace '"./investments.sh"' '"investments.sh"' \
          --replace '"./mortgage_interest.sh"' '"mortgage_interest.sh"' \
          --replace '"./tax_return.sh"' '"tax_return.sh"' \
          --replace '"./budget.sh"' '"budget.sh"'
        '';
      })
    ];

    preConfigure = ''

          patchShebangs **/export.hs
          patchShebangs **/in2csv
          patchShebangs **/csv2journal
          patchShebangs **/matching_rules.py

          # patch parameters for the shake tool being run
          substituteInPlace {01-getting-started,02-getting-data-in,03-getting-full-history,04-adding-more-accounts,05-creating-csv-import-rules,06-maintaining-lots-of-csv-rules,07-investments-easy-approach,08-mortgage,09-remortgage,10-foreign-currency,11-sorting-unknowns,12-file-specific-rules,13-tax-returns,14-speeding-up,15-manual-lots}/export.sh \
          --replace '$(dirname $0)/export/export.hs -C $(dirname $0)/export -j --color "$@"' 'export.hs -C export -j --color "$@"'

          substituteInPlace {08-mortgage,09-remortgage,10-foreign-currency,11-sorting-unknowns,12-file-specific-rules,13-tax-returns,14-speeding-up,15-manual-lots}/export/mortgage_interest.sh \
          --replace '"''${dir}/../''${year}.journal' '"../''${year}.journal'

          substituteInPlace {13-tax-returns,14-speeding-up,15-manual-lots}/export/tax_return.sh \
          --replace ' ''${dir}/' " "

#          substituteInPlace 15-manual-lots/export/budget.sh \
#          --replace ' ''${dir}/' " " \
#          --replace ' "''${dir}/' ' "'

      ###    substituteInPlace {11-sorting-unknowns,12-file-specific-rules,13-tax-returns,14-speeding-up,15-manual-lots}/resolve.sh \
         ### --replace './export/' "" \
         ### --replace './import/' '../import/'
      #    --replace './import/*' '../import/*' \
      #    --replace '"./import/' '"../import/'

      #    --replace '$(dirname $0)/export/export.hs -C $(dirname $0)/export -j --color "$@"' "pushd \$(dirname \$0)/export && $ { (haskell.packages.ghc946.ghcWithHoogle (pset: with pset; [ shake ]))}/bin/runhaskell export.hs"

      #for f in $(find {01-getting-started,02-getting-data-in,03-getting-full-history,04-adding-more-accounts,05-creating-csv-import-rules,06-maintaining-lots-of-csv-rules,07-investments-easy-approach,08-mortgage,09-remortgage,10-foreign-currency,11-sorting-unknowns,12-file-specific-rules,13-tax-returns,14-speeding-up,15-manual-lots}/{export,resolve}.sh -type f -executable); do
      #    wrapProgram "$f" \
      #      --prefix PATH : $ { lib.makeBinPath [ skim csvtool ripgrep python3 parallel hledger hledger-interest (haskell.packages.ghc946.ghcWithHoogle (pset: with pset; [ shake ])) ]}
      #done
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r ./* $out
      runHook postInstall
    '';

    meta = {
      description = "full-fledged-hledger";
      longDescription = ''
        full-fledged-hledger
      '';
      homepage = https://github.com/adept/full-fledged-hledger;
      #    license = licenses.bsd3;
      #    platforms = platforms.unix;
    };
  }

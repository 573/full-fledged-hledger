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

  documentNames = builtins.attrNames (filterAttrs (k: v: (v == "directory" && k != "diffs" && k != "z98-budgeting" && !hasPrefix "." k)) (builtins.readDir ./.));

  inherit
    (lib)
    filterAttrs
    hasPrefix
    drop
    ;
in
  stdenvNoCC.mkDerivation rec {
    name = "full-fledged-hledger";

    nativeBuildInputs = [makeWrapper];
    propagatedBuildInputs = [hledger stack python3 parallel];

    src = with builtins;
      filterSource
      (path: _:
        !elem (baseNameOf path) [".git" "result" "bin" "_build" "_build_ci" "_build_vo" "nix" ".stack"])
      ./.;

    patches = [
      (mkPatch {
        name = "use-runhaskell";
        inherit src;
        patchCommands = lib.foldl' (s: i:
          s
          + ''
            set -eux
            substituteInPlace "${i}/export/export.hs" --replace 'env stack' 'env runhaskell' --replace '"./in2csv"' '"in2csv"' --replace '"./csv2journal"' '"csv2journal"' --replace '"./investments.sh"' '"investments.sh"' --replace '"./mortgage_interest.sh"' '"mortgage_interest.sh"' --replace '"./tax_return.sh"' '"tax_return.sh"' --replace '"./budget.sh"' '"budget.sh"'
          '') ""
        documentNames;
      })
    ];

    preConfigure =
      (lib.foldl' (s: i:
        s
        + ''

          patchShebangs **/export.hs
          patchShebangs **/in2csv
          patchShebangs **/csv2journal
          patchShebangs **/matching_rules.py
          patchShebangs **/investments.sh
          patchShebangs **/mortgage_interest.sh
          patchShebangs **/pension.sh
          patchShebangs **/price_dates.sh
          patchShebangs **/prices.sh
          patchShebangs **/stock-options.sh

          # patch parameters for the shake tool being run
          substituteInPlace "${i}/export.sh" --replace '$(dirname $0)/export/export.hs -C $(dirname $0)/export -j --color "$@"' 'export.hs -C export -j --color "$@"'
        '') ""
      documentNames)
      + (lib.foldl' (s: i:
        s
        + ''
          substituteInPlace "${i}/export/mortgage_interest.sh" --replace '"''${dir}/../''${year}.journal' '"../''${year}.journal'
        '') "" (drop 7 documentNames))
      + (lib.foldl' (s: i:
        s
        + ''
          substituteInPlace "${i}/export/tax_return.sh" --replace ' ''${dir}/' " "
        '') "" (drop 12 documentNames))
      + (lib.foldl' (s: i:
        s
        + ''
          substituteInPlace "${i}/export/pension.sh" --replace 'cd $(dirname $0)' ""

          substituteInPlace "${i}/export/stock-options.sh" --replace 'cd $(dirname $0)' "" --replace './import' 'import'
     '') "" (drop 14 documentNames)) 
      + (lib.foldl' (s: i:
        s
        + ''
          substituteInPlace "${i}/export/price_dates.sh" --replace '$(dirname $0)' '.'
          substituteInPlace "${i}/export/export.hs" --replace '"./price_dates.sh"' '"price_dates.sh"' --replace '"./prices.sh"' '"prices.sh"' --replace '"./pension.sh"' '"pension.sh"' --replace '"./stock-options.sh"' '"stock-options.sh"'
        '') "" (drop 15 documentNames))
	;

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
      homepage = "https://github.com/adept/full-fledged-hledger";
      #    license = licenses.bsd3;
      #    platforms = platforms.unix;
    };
  }

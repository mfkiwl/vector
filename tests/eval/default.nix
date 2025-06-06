{
  lib,
  linkerScript,
  makeBuilder,
  findAndBuild,
  t1main,
  getTestRequiredFeatures,
  callPackage,
}:

let
  builder = makeBuilder { casePrefix = "eval"; };
  build =
    { caseName, sourcePath }:
    builder {
      inherit caseName;

      src = sourcePath;

      passthru.featuresRequired = getTestRequiredFeatures sourcePath;
      isFp = lib.pathExists (lib.path.append sourcePath "isFp");

      buildPhase = ''
        runHook preBuild

        $CC -T${linkerScript} \
          *.{c,S} \
          ${t1main} \
          -o $pname.elf

        runHook postBuild
      '';

      meta.description = "test case '${caseName}', written in C assembly";
    };
  autoCases = findAndBuild ./. build;

  nttCases = callPackage ./_ntt { };
in
autoCases // nttCases

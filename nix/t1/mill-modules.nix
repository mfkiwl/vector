{ lib
, stdenv
, fetchMillDeps
, makeWrapper
, jdk21

  # chisel deps
, mill
, espresso
, circt-full
, jextract-21
, add-determinism

, dependencies
}:

let
  self = stdenv.mkDerivation rec {
    name = "t1-all-mill-modules";

    src = with lib.fileset; toSource {
      root = ./../..;
      fileset = unions [
        ./../../build.sc
        ./../../common.sc
        ./../../t1
        ./../../omreader
        ./../../omreaderlib
        ./../../t1emu/src
        ./../../elaborator
        ./../../configgen/src
        ./../../rocketv
        ./../../t1rocket/src
        ./../../t1rocketemu/src
        ./../../rocketemu/src
        ./../../.scalafmt.conf
      ];
    };

    passthru.millDeps = fetchMillDeps {
      inherit name;
      src = with lib.fileset; toSource {
        root = ./../..;
        fileset = unions [
          ./../../build.sc
          ./../../common.sc
          ./../../.scalafmt.conf
        ];
      };
      millDepsHash = "sha256-gBxEO6pGD0A1RxZW2isjPcHDf+b9Sr++7eq6Ezngiio=";
      nativeBuildInputs = [ dependencies.setupHook ];
    };

    passthru.editable = self.overrideAttrs (_: {
      shellHook = ''
        setupSubmodulesEditable
        mill mill.bsp.BSP/install 0
      '';
    });

    shellHook = ''
      setupSubmodules
    '';

    nativeBuildInputs = [
      mill
      circt-full
      jextract-21
      add-determinism
      espresso

      makeWrapper
      passthru.millDeps.setupHook

      dependencies.setupHook
    ];

    env = {
      CIRCT_INSTALL_PATH = circt-full;
      JEXTRACT_INSTALL_PATH = jextract-21;
    };

    outputs = [ "out" "configgen" "elaborator" "t1package" ];

    # Check code format before starting build, so that we can enforce all developer run reformat before build.
    configurePhase = ''
      runHook preConfigure

      _targetsToCheck=(
        "configgen"
        "elaborator"
        "omreader"
        "omreaderlib"
        "rocketemu"
        "rocketv"
        "t1"
        "t1emu"
        "t1rocket"
        "t1rocketemu"
      )
      for _t in ''${_targetsToCheck[@]}; do
        if ! mill -i "$_t".checkFormat; then
          echo "[ERROR] Please run 'mill -i $_t.reformat' before elaborate!" >&2
          exit 1
        fi
      done
      unset _targetsToCheck

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      mill -i '__.assembly'

      mill -i t1package.sourceJar
      mill -i t1package.chiselPluginJar

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p $out/share/java

      add-determinism-q() {
        add-determinism $@ >/dev/null
      }
      add-determinism-q out/elaborator/assembly.dest/out.jar
      add-determinism-q out/configgen/assembly.dest/out.jar
      add-determinism-q out/t1package/assembly.dest/out.jar
      add-determinism-q out/t1package/sourceJar.dest/out.jar
      add-determinism-q out/t1package/chiselPluginJar.dest/out.jar

      mv out/configgen/assembly.dest/out.jar $out/share/java/configgen.jar
      mv out/elaborator/assembly.dest/out.jar $out/share/java/elaborator.jar

      mkdir -p $t1package/share/java
      mv out/t1package/sourceJar.dest/out.jar $t1package/share/java/t1package-sources.jar
      mv out/t1package/assembly.dest/out.jar $t1package/share/java/t1package.jar
      mv out/t1package/chiselPluginJar.dest/out.jar $t1package/share/java/chiselPluginJar.jar

      mkdir -p $configgen/bin $elaborator/bin
      makeWrapper ${jdk21}/bin/java $configgen/bin/configgen --add-flags "-jar $out/share/java/configgen.jar"
      makeWrapper ${jdk21}/bin/java $elaborator/bin/elaborator --add-flags "--enable-preview -Djava.library.path=${circt-full}/lib -cp $out/share/java/elaborator.jar org.chipsalliance.t1.elaborator.Main"
    '';
  };
in
self

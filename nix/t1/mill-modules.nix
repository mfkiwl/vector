{
  lib,
  stdenv,
  makeWrapper,
  runCommand,
  jdk21,

  # chisel deps
  mill,
  git,
  espresso,
  circt-install,
  mlir-install,
  jextract-21,
  add-determinism,
  writeShellApplication,
  glibcLocales,

  submodules,
  ivy-gather,
  mill-ivy-env-shell-hook,
  mill-ivy-fetcher,
}:

let
  t1MillDeps = ivy-gather ../../dependencies/locks/t1-lock.nix;

  self = stdenv.mkDerivation rec {
    name = "t1-all-mill-modules";

    src =
      with lib.fileset;
      toSource {
        root = ./../..;
        fileset = unions [
          ./../../build.mill
          ./../../common.mill
          ./../../t1
          ./../../omreader
          ./../../t1emu/src
          ./../../elaborator
          ./../../rocketv
          ./../../t1rocket/src
          ./../../t1rocketemu/src
          ./../../stdlib/src
          ./../../custom-instructions
        ];
      };

    buildInputs = with submodules; [
      riscv-opcodes
      ivy-arithmetic.setupHook
      ivy-chisel.setupHook
      ivy-omlib.setupHook
      ivy-chisel-interface.setupHook
      ivy-rvdecoderdb.setupHook
      ivy-hardfloat.setupHook
      t1MillDeps
    ];

    nativeBuildInputs = [
      mill
      circt-install
      mlir-install
      jextract-21
      add-determinism
      espresso
      git

      makeWrapper
    ];

    env = {
      CIRCT_INSTALL_PATH = circt-install;
      MLIR_INSTALL_PATH = mlir-install;
      JEXTRACT_INSTALL_PATH = jextract-21;
    };

    passthru.bump = writeShellApplication {
      name = "bump-t1-mill-lock";
      runtimeInputs = [
        mill
        mill-ivy-fetcher
      ];
      text = ''
        ivyLocal="${submodules.ivyLocalRepo}"
        export JAVA_TOOL_OPTIONS="''${JAVA_TOOL_OPTIONS:-} -Dcoursier.ivy.home=$ivyLocal -Divy.home=$ivyLocal"

        mif run -p "${src}" -o ./dependencies/locks/t1-lock.nix "$@"
      '';
    };

    shellHook = ''
      ${mill-ivy-env-shell-hook}

      mill -i mill.bsp.BSP/install
    '';

    outputs = [
      "out"
      "omreader"
      "elaborator"
    ];

    buildPhase = ''
      runHook preBuild

      # Mill assume path string is always encoded in UTF-8. However in Nix
      # build environment, locale type is set to "C", and breaks the assembly
      # JAR class path. Here is the workaround for the Scala build environment.
      export LOCALE_ARCHIVE="${glibcLocales}/lib/locale/locale-archive"
      export LANG="en_US.UTF-8";

      mill -i '__.assembly'

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p $out/share/java

      # Align datetime
      export SOURCE_DATE_EPOCH=1669810380
      add-determinism-q() {
        add-determinism $@ >/dev/null
      }
      add-determinism-q out/elaborator/assembly.dest/out.jar
      add-determinism-q out/omreader/assembly.dest/out.jar

      mv out/elaborator/assembly.dest/out.jar $out/share/java/elaborator.jar
      mv out/omreader/assembly.dest/out.jar "$out"/share/java/omreader.jar

      mkdir -p $elaborator/bin
      makeWrapper ${jdk21}/bin/java $elaborator/bin/elaborator \
        --add-flags "--enable-preview -Djava.library.path=${mlir-install}/lib:${circt-install}/lib" \
        --add-flags "-cp $out/share/java/elaborator.jar"

      mkdir -p $omreader/bin
      makeWrapper ${jdk21}/bin/java "$omreader"/bin/omreader \
        --add-flags "--enable-preview" \
        --add-flags "--enable-native-access=ALL-UNNAMED" \
        --add-flags "-Djava.library.path=${mlir-install}/lib:${circt-install}/lib" \
        --add-flags "-cp $out/share/java/omreader.jar"
    '';
  };
in
self

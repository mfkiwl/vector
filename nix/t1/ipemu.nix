{ stdenv
, lib

  # emulator deps
, cmake
, libargs
, spdlog
, fmt
, libspike
, nlohmann_json
, ninja
, verilator
, zlib

, rtl
, config-name

, do-trace ? false
}:

stdenv.mkDerivation {
  name = "t1-${config-name}-ipemu" + lib.optionalString do-trace "-trace";

  src = ../../ipemu/csrc;

  # CMakeLists.txt will read the environment
  env.VERILATE_SRC_DIR = toString rtl;

  cmakeFlags = lib.optionals do-trace [
    "-DVERILATE_TRACE=ON"
  ];

  nativeBuildInputs = [
    cmake
    verilator
    ninja
  ];

  buildInputs = [
    zlib
    libargs
    spdlog
    fmt
    libspike
    nlohmann_json
  ];

  meta = {
    mainProgram = "emulator";
    description = "IP emulator for config ${config-name}";
  };
}
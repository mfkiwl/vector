{
  description = "vector";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    mill-ivy-fetcher.url = "github:Avimitin/mill-ivy-fetcher";
    circt-follow.url = "github:sequencer/zaozi";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      mill-ivy-fetcher,
      circt-follow,
      ...
    }:
    let
      overlay = import ./nix/overlay.nix;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # Add supported platform here
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      flake = {
        # Export github:chipsalliance/t1.overlays.t1-overlay to help other project have share package override
        overlays = rec {
          t1-overlay = overlay;

          default = t1-overlay;
        };
      };

      imports = [
        # Add treefmt flake module to automatically configure and add formatter to this flake
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              mill-ivy-fetcher.overlays.default
              # Follow CIRCT from sequencer/zaozi overlay
              circt-follow.overlays.default
              overlay
            ];
          };
        in
        {
          # Override the default "pkgs" attribute in per-system config.
          _module.args.pkgs = pkgs;

          # Although the pkgs attribute is already override, but I am afraid
          # that the magical evaluation of "pkgs" is confusing, and will lead
          # to debug hell. So here we use the "pkgs" in "let-in binding" to
          # explicitly told every user we are using an overlayed version of
          # nixpkgs.
          legacyPackages = pkgs;

          devShells = {
            default = pkgs.mkShell {
              buildInputs = with pkgs; [
                ammonite
                mill
                t1-helper
                zstd
              ];
            };
          };

          treefmt = {
            projectRootFile = "flake.nix";
            settings.on-unmatched = "debug";
            programs = {
              nixfmt.enable = true;
              scalafmt.enable = true;

              # treefmt-nix can not determine edition automatically,
              # unlike 'cargo fmt' which reads from Cargo.toml.
              #
              # rustfmt.enable = true;
            };
            settings.formatter = {
              nixfmt.excludes = [ "*/generated.nix" ];
              scalafmt.includes = [
                "*.sc"
                "*.mill"
              ];
            };
          };
        };
    };
}

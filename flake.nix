{
  description = "University: Bachelor Semester Project 5 (2024/09/16--2025/01/31)";

  inputs = {
    "1brc" = {
      flake = false;
      url = "github:gunnarmorling/1brc";
    };

    advisory-db = {
      flake = false;
      url = "github:rustsec/advisory-db";
    };

    crane.url = "github:ipetkov/crane";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      inputs.systems.follows = "systems";
      url = "github:numtide/flake-utils";
    };

    git-hooks = {
      inputs = {
        flake-compat.follows = "";
        nixpkgs.follows = "nixpkgs";
      };

      url = "github:cachix/git-hooks.nix";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system: let
        inherit (pkgs) lib;

        crane = lib.fix (
          self: {
            args = {
              inherit (self) src;

              buildInputs = lib.optionals pkgs.stdenv.isDarwin [pkgs.libiconv];

              meta = let
                inherit ((lib.importTOML ./Cargo.toml).workspace) package;
              in {
                inherit (package) description homepage;

                license = lib.getLicenseFromSpdxId package.license;
                maintainers = [lib.maintainers.naho];
              };

              strictDeps = true;
            };

            buildPackage = args:
              self.lib.buildPackage (
                self.args
                // {
                  inherit
                    (self.lib.crateNameFromCargoToml {inherit (self) src;})
                    version
                    ;

                  inherit (self) cargoArtifacts;

                  doCheck = false;
                }
                // args
              );

            cargoArtifacts = self.lib.buildDepsOnly self.args;

            src = lib.cleanSourceWith {
              filter = path: type:
                type
                == "regular"
                && lib.hasSuffix "assets/output-1000000000.txt" path
                || self.lib.filterCargoSources path type;

              name = "source";
              src = ./.;
            };

            lib = (inputs.crane.mkLib pkgs).overrideToolchain (
              inputs.fenix.packages.${system}.default.withComponents
              ["cargo" "clippy" "rustc" "rustfmt"]
            );

            workspace.src = workspaces:
              lib.fileset.toSource {
                fileset = lib.fileset.unions (
                  workspaces ++ [./Cargo.lock ./Cargo.toml ./crates/hakari]
                );

                root = ./.;
              };
          }
        );

        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in {
        checks =
          lib.attrsets.unionOfDisjoint
          inputs.self.packages.${system}
          {
            cargo-audit = crane.lib.cargoAudit {
              inherit (crane) src;
              inherit (inputs) advisory-db;
            };

            cargo-clippy = crane.lib.cargoClippy (
              crane.args
              // {
                inherit (crane) cargoArtifacts;
                cargoClippyExtraArgs = "--all-targets -- --deny warnings";
              }
            );

            cargo-deny = crane.lib.cargoDeny {inherit (crane) src;};
            cargo-fmt = crane.lib.cargoFmt {inherit (crane) src;};

            cargo-hakari = crane.lib.mkCargoDerivation {
              inherit (crane) src;

              buildPhaseCargoCommand = ''
                cargo hakari generate --diff
                cargo hakari manage-deps --dry-run
                cargo hakari verify
              '';

              cargoArtifacts = null;
              doInstallCargoArtifacts = false;
              name = "cargo-hakari";
              nativeBuildInputs = [pkgs.cargo-hakari];
            };

            cargo-nextest = crane.lib.cargoNextest (
              crane.args
              // {
                inherit (crane) cargoArtifacts;

                postPatch = let
                  input = inputs.self.packages.${system}.input-1000000000;
                in ''
                  substituteInPlace \
                    crates/lib/src/solution.rs \
                    --replace-fail {../../assets,${input}}/input-
                '';
              }
            );

            cargo-test-doc = crane.lib.cargoDocTest (
              crane.args // {inherit (crane) cargoArtifacts;}
            );

            git-hooks = inputs.git-hooks.lib.${system}.run {
              hooks = {
                alejandra = {
                  enable = true;
                  settings.verbosity = "quiet";
                };

                deadnix.enable = true;
                statix.enable = true;
                typos.enable = true;
                yamllint.enable = true;
              };

              src = ./.;
            };

            taplo-fmt = crane.lib.taploFmt {
              src = lib.sources.sourceFilesBySuffices crane.src [".toml"];
            };
          };

        devShells.default = crane.lib.devShell {
          inherit (inputs.self.checks.${system}.git-hooks) shellHook;

          checks = inputs.self.checks.${system};

          packages = [
            inputs.self.checks.${system}.git-hooks.enabledPackages
            pkgs.cargo-hakari
          ];
        };

        formatter = pkgs.alejandra;

        packages = lib.fix (
          self:
            builtins.foldl' lib.attrsets.unionOfDisjoint {} (
              (
                map
                (
                  workspace: let
                    package = {inputDefault ? true}: args: let
                      assets =
                        if inputDefault
                        then inputs.self.packages.${system}.input-1000000000
                        else
                          pkgs.buildEnv {
                            name = "input-default";

                            paths =
                              lib.attrValues
                              (
                                lib.attrsets.filterAttrs
                                (name: _: lib.hasPrefix "input-" name)
                                self
                              );
                          };
                    in
                      crane.buildPackage (
                        {
                          cargoExtraArgs = "--package ${workspace}";
                          meta.mainProgram = workspace;

                          postInstall = ''
                            mkdir --parent $out/assets

                            cp \
                              --no-preserve=mode \
                              --recursive \
                              ${assets}/. \
                              $out/assets

                            find $out
                          '';

                          postPatch = ''
                            substituteInPlace \
                              crates/lib/src/solution.rs \
                              --replace-fail ../../assets ${assets}
                          '';

                          src = crane.workspace.src [
                            (lib.path.append ./crates workspace)
                            crates/lib
                          ];
                        }
                        // args
                      );
                  in {
                    "${workspace}-bench" = let
                      bench = builtins.replaceStrings ["-"] ["_"] workspace;
                    in
                      package {inputDefault = false;} {
                        __impure = true;
                        buildPhaseCargoCommand = "cargo bench -- ${bench}";
                        doNotPostBuildInstallCargoBinaries = true;

                        installPhase = ''
                          install -D \
                            --target-directory $out \
                            "''${CARGO_TARGET_DIR:-target}/criterion/${bench}/report/"*.svg
                        '';
                      };

                    "${workspace}-dev" = package {} {CARGO_PROFILE = "dev";};

                    "${workspace}-flamegraph" = pkgs.writeShellApplication {
                      name = "${workspace}-flamegraph";

                      text = ''
                        directory="$(mktemp --directory)"

                        cleanup() {
                          rm --recursive "$directory"
                        }

                        trap cleanup EXIT

                        cd "$directory"

                        flamegraph \
                          --deterministic \
                          --output "''${1:-$(mktemp --suffix .svg)}" \
                          -- \
                          ${lib.getExe self."${workspace}-dev"}
                      '';

                      runtimeInputs = [pkgs.cargo-flamegraph];
                    };

                    "${workspace}-release" = package {} {};
                  }
                )
                (
                  builtins.filter
                  (directory: directory != "hakari" && directory != "lib")
                  (builtins.attrNames (builtins.readDir ./crates))
                )
              )
              ++ (
                map
                (
                  size: let
                    name = "input-${size}";
                  in {
                    ${name} = pkgs.stdenvNoCC.mkDerivation {
                      inherit name;

                      buildPhase = ''
                        (
                          cd src/main/python || exit
                          python3 create_measurements.py ${size}
                        )
                      '';

                      installPhase = ''
                        install -D data/measurements.txt $out/${name}.txt
                      '';

                      nativeBuildInputs = [pkgs.python3];
                      src = inputs."1brc";
                    };
                  }
                )
                (
                  map toString [
                    10000
                    100000
                    1000000
                    10000000
                    100000000
                    1000000000
                  ]
                )
              )
              ++ [
                (
                  let
                    packages = profile: let
                      name = "packages-${profile}";
                    in
                      pkgs.buildEnv {
                        inherit name;

                        paths = lib.attrsets.attrValues (
                          lib.filterAttrs
                          (package: _: lib.hasSuffix "-${profile}" package)
                          (builtins.removeAttrs self [name])
                        );
                      };
                  in {
                    default = pkgs.buildEnv {
                      name = "default";
                      paths = with self; [docs packages-release];
                    };

                    packages-dev = packages "dev";
                    packages-release = packages "release";
                  }
                )

                {
                  diff = pkgs.stdenvNoCC.mkDerivation {
                    buildPhase = let
                      out = "${placeholder "out"}/share/doc";
                    in ''
                      mkdir --parent ${out}

                      mapfile -t files < <(
                        printf '%s\n' iteration-*/src/lib.rs
                      )

                      previous_file=/dev/null

                      for i in "''${!files[@]}"; do
                          current_file="''${files[i]}"

                          status=0

                          diff \
                            --unified \
                            --label "/''${previous_file#/}" \
                            --label "/$current_file" \
                            "$previous_file" \
                            "$current_file" \
                            >"${out}/$(
                              printf '%s' "$current_file" |
                                tr --complement '[:alnum:]' _
                            ).diff" || status="$?"

                          if ((status != 1)); then
                            exit "$((status + 1))"
                          fi

                          previous_file="$current_file"
                      done
                    '';

                    name = "diff";
                    nativeBuildInputs = [pkgs.diffutils];
                    src = ./crates;
                  };

                  docs = crane.lib.cargoDoc (
                    crane.args // {inherit (crane) cargoArtifacts;}
                  );
                }
              ]
            )
        );
      }
    );
}

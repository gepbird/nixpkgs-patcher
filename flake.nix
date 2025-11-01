{
  description = "Add patches to nixpkgs seamlessly";

  outputs =
    { self }:
    {
      lib = {
        nixosSystem =
          args:
          let
            inherit (builtins)
              match
              removeAttrs
              substring
              ;

            inherit (nixpkgs.lib)
              attrsToList
              filterAttrs
              ;

            die = msg: throw "[nixpkgs-patcher]: ${msg}";

            # maybe try to import the flake instead, this is for mostly replicating nixosSystem from the flake:
            # https://github.com/NixOS/nixpkgs/blob/a61befb69a171c7fe6fb141fca18e40624d7f55f/flake.nix#L64-L95
            metadataModule =
              { lib, ... }:
              {
                config.nixpkgs.flake.source = toString patchedNixpkgs;

                config.system.nixos.versionSuffix = ".${
                  lib.substring 0 8 nixpkgs.lastModifiedDate or "19700101"
                }.${nixpkgs.shortRev or "dirty"}${if patches != [ ] then "-patched" else ""}";

                config.system.nixos.revision = nixpkgs.rev or "dirty";
              };

            nixpkgsPatcherNixosModule =
              { lib, ... }:

              let
                inherit (lib)
                  mkOption
                  mkEnableOption
                  literalExpression
                  types
                  ;
              in
              {
                options.nixpkgs-patcher = {
                  enable = mkEnableOption "nixpkgs-patcher";
                  settings = mkOption {
                    type = types.submodule {
                      options = {
                        patches = lib.mkOption {
                          type = types.listOf (types.either types.path types.package);
                          default = [ ];
                          example = literalExpression ''
                            [
                              (pkgs.fetchurl {
                                name = "foo-module-init.patch";
                                url = "https://github.com/NixOS/nixpkgs/compare/pull/123456/head~1...pull/123456/head.patch";
                                hash = "";
                              })
                            ]
                          '';
                          description = ''
                            A list of patches to apply to the nixpkgs source.
                          '';
                        };
                      };
                    };
                    default = { };
                  };
                };
              };

            dontCheckModule = {
              # disable checking for "The option `services.xyz.enable' does not exist" and other errors
              # this is a common error when using a module init patch
              _module.check = false;
            };

            args' = {
              system = null;
              modules = args.modules ++ [
                metadataModule
                nixpkgsPatcherNixosModule
              ];
            }
            // removeAttrs args [
              "modules"
              "nixpkgsPatcher"
            ];

            config = args.nixpkgsPatcher or { };
            inputs =
              config.inputs or args.specialArgs
                or (die "Couldn't find your flake inputs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.inputs = inputs` or `specialArgs = inputs`.");
            nixpkgs =
              config.nixpkgs or inputs.nixpkgs
                or (die "Couldn't find your base nixpkgs. You need to pass the nixosSystem function an attrset with `nixpkgsPatcher.nixpkgs = inputs.nixpkgs` or name your main nixpkgs input `nixpkgs` and pass `specialArgs = inputs`.");
            patchInputRegex = config.patchInputRegex or "^nixpkgs-patch-.*";
            patchesFromConfig = config.patches or (_: [ ]);

            evalArgs = args' // {
              modules = args'.modules ++ [ dontCheckModule ];
            };
            evaledModules = import "${nixpkgs}/nixos/lib/eval-config.nix" evalArgs;
            system =
              config.system or (
                if args'.system != null then args'.system else evaledModules.config.nixpkgs.hostPlatform.system
              );
            pkgs = import nixpkgs { inherit system; };

            moduleConfig = evaledModules.config.nixpkgs-patcher;
            patchesFromModules = if moduleConfig.enable then moduleConfig.settings.patches else [ ];

            patchesFromFlakeInputsRaw = attrsToList (
              filterAttrs (n: v: match patchInputRegex n != null) inputs
            );
            # this is for setting a nicer name for the patch in the build log
            patchesFromFlakeInputs = map (
              patch:
              pkgs.stdenvNoCC.mkDerivation {
                inherit (patch) name;

                phases = [ "installPhase" ];
                installPhase = ''
                  cp -r ${patch.value.outPath} $out
                '';
              }
            ) patchesFromFlakeInputsRaw;

            patches = patchesFromFlakeInputs ++ (patchesFromConfig pkgs) ++ patchesFromModules;
            patchedNixpkgs = pkgs.applyPatches {
              name = "nixpkgs-${substring 1 (-1) evaledModules.config.system.nixos.versionSuffix}";
              src = nixpkgs;

              inherit patches;

              nativeBuildInputs = with pkgs; [
                bat
                breakpointHook
              ];

              failureHook = ''
                failedPatches=$(find . -name "*.rej")
                for failedPatch in $failedPatches; do
                  echo "────────────────────────────────────────────────────────────────────────────────"
                  originalFile="${nixpkgs}/''${failedPatch%.rej}"
                  echo "Original file without any patches: $originalFile"
                  echo "Failed hunks of this file:"
                  bat --pager never --style plain $failedPatch
                done

                echo "────────────────────────────────────────────────────────────────────────────────"
                echo "Applying some patches failed. Check the build log above this message."
                echo "Visit https://github.com/gepbird/nixpkgs-patcher/blob/main/doc/troubleshooting.md for help."
                echo "You can inspect the state of the patched nixpkgs by attaching to the build shell, or press Ctrl+C to exit:"
                # breakpontHook message gets inserted here
              '';
            };
            finalNixpkgs = if patches == [ ] then nixpkgs else patchedNixpkgs;

            nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix" args';
          in
          nixosSystem;
      };
    };
}

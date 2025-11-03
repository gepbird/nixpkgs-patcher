{
  description = "Add patches to nixpkgs seamlessly";

  outputs =
    _:
    let
      die = msg: throw "[nixpkgs-patcher]: ${msg}";

      defaultPatchInputRegex = "^nixpkgs-patch-.*";

      patchesFromFlakeInputs =
        {
          inputs,
          patchInputRegex,
          pkgs,
        }:
        let
          patches = pkgs.lib.attrsToList (
            pkgs.lib.filterAttrs (n: v: builtins.match patchInputRegex n != null) inputs
          );
          addPatchNameInDerivation =
            patch:
            pkgs.stdenvNoCC.mkDerivation {
              inherit (patch) name;

              phases = [ "installPhase" ];
              installPhase = ''
                cp -r ${patch.value.outPath} $out
              '';
            };
        in
        map addPatchNameInDerivation patches;

      nixpkgsVersion =
        {
          nixpkgs,
          patches,
        }:
        "${
          nixpkgs.lib.substring 0 8 nixpkgs.lastModifiedDate or "19700101"
        }.${nixpkgs.shortRev or "dirty"}${if patches != [ ] then "-patched" else ""}";

      patchNixpkgsRaw =
        {
          nixpkgs,
          patches,
          pkgs,
        }:
        pkgs.applyPatches {
          name = "nixpkgs-${nixpkgsVersion { inherit nixpkgs patches; }}";
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
    in
    {
      lib = {
        patchNixpkgs =
          {
            inputs ? null,
            nixpkgs ? null,
            patchInputRegex ? defaultPatchInputRegex,
            patches ? null,
            pkgs ? null,
            system ? null,
          }@args:
          let
            nixpkgs' =
              args.nixpkgs or args.inputs.nixpkgs
                or (die "Couldn't find your base nixpkgs when calling `patchNixpkgs`. You need to pass `nixpkgs` or have a flake input named `nixpkgs` and pass your `inputs`.");
            pkgs' =
              if pkgs != null then
                pkgs
              else if system != null then
                import nixpkgs' { inherit system; }
              else
                (die "Couldn't get `pkgs` when calling `patchNixpkgs`. You need to pass your `pkgs` or `system`.");

            maybePatchesFromFlakeInputs =
              if inputs != null then
                patchesFromFlakeInputs {
                  inherit inputs patchInputRegex;
                  pkgs = pkgs';
                }
              else
                [ ];
            maybePatches = args.patches or [ ];
            maybePatchesList =
              if builtins.typeOf maybePatches == "lambda" then maybePatches pkgs' else maybePatches;
            patches' =
              if inputs == null && patches == null then
                (die "Couldn't find any patches when calling `patchNixpkgs`. You need to pass your flake inputs as `inputs` or a list of patches as `patches` or pass both.")
              else
                maybePatchesFromFlakeInputs ++ maybePatchesList;

            patchedNixpkgs = patchNixpkgsRaw {
              nixpkgs = nixpkgs';
              patches = patches';
              pkgs = pkgs';
            };
          in
          patchedNixpkgs;

        nixosSystem =
          args:
          let
            metadataModule = {
              config.nixpkgs.flake.source = toString patchedNixpkgs;

              config.system.nixos.versionSuffix = ".${nixpkgsVersion { inherit nixpkgs patches; }}";

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
            // builtins.removeAttrs args [
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
            patchInputRegex = config.patchInputRegex or defaultPatchInputRegex;
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

            patches =
              (patchesFromFlakeInputs { inherit inputs patchInputRegex pkgs; })
              ++ (patchesFromConfig pkgs)
              ++ patchesFromModules;

            patchedNixpkgs = patchNixpkgsRaw { inherit nixpkgs patches pkgs; };
            finalNixpkgs = if patches == [ ] then nixpkgs else patchedNixpkgs;

            nixosSystem = import "${finalNixpkgs}/nixos/lib/eval-config.nix" args';
          in
          nixosSystem;
      };
    };
}

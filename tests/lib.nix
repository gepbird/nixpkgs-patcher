{ nixpkgs, system }:

let
  inherit (nixpkgs) lib;
  pkgs = import nixpkgs { inherit system; };

  runTests =
    tests:
    let
      failedTests = lib.debug.runTests tests;
    in
    if (builtins.length failedTests) != 0 then throw (builtins.toJSON failedTests) else pkgs.hello;

  testBuilds = drv: {
    expr = builtins.typeOf (builtins.readDir drv);
    expected = "set";
  };

  testNixosConfigurationBuilds =
    nixosConfiguration: testBuilds nixosConfiguration.config.system.build.toplevel;
in
{
  inherit
    runTests
    testBuilds
    testNixosConfigurationBuilds
    ;
}

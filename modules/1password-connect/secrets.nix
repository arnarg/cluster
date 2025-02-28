{
  lib,
  config,
  ...
}: let
  opSecretOpts = {name, ...}: {
    options = with lib; {
      vault = mkOption {
        type = types.str;
        default = "Cluster";
      };
      itemName = mkOption {
        type = types.str;
      };
    };
  };
in {
  options = with lib; {
    opSecrets = mkOption {
      type = with types; attrsOf (submodule opSecretOpts);
      default = {};
    };
  };

  config = {
    resources.onePasswordItems =
      lib.mapAttrs (n: v: {
        spec.itemPath = "vaults/${v.vault}/items/${v.itemName}";
      })
      config.opSecrets;
  };
}

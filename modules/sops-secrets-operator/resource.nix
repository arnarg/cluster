{
  lib,
  config,
  options,
  ...
}: let
  submoduleOf = ref:
    lib.types.submodule ({name, ...}: {
      options = config.definitions."${ref}".options or {};
      config = config.definitions."${ref}".config or {};
    });

  getDefaults = with lib;
    resource: group: version: kind:
      catAttrs "default" (filter
        (
          default:
            (default.resource == null || default.resource == resource)
            && (default.group == null || default.group == group)
            && (default.version == null || default.version == version)
            && (default.kind == null || default.kind == kind)
        )
        config.defaults);

  submoduleForDefinition = with lib;
    ref: resource: kind: group: version: let
      apiVersion =
        if group == "core"
        then version
        else "${group}/${version}";
    in
      types.submodule ({name, ...}: {
        imports = getDefaults resource group version kind;
        options = definitions."${ref}".options;
        config = mkMerge [
          definitions."${ref}".config
          {
            kind = mkOptionDefault kind;
            apiVersion = mkOptionDefault apiVersion;

            # metdata.name cannot use option default, due deep config
            metadata.name = mkOptionDefault name;
          }
        ];
      });
  definitions = with lib; {
    "isindir.github.com.v1alpha3.SopsSecret" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (submoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          type = with types; nullOr (attrsOf anything);
        };
        "sops" = mkOption {
          type = with types; nullOr (attrsOf anything);
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "sops" = mkOverride 1002 null;
      };
    };
  };
in {
  options.resources = with lib; {
    "isindir.github.com"."v1alpha3"."SopsSecret" = mkOption {
      type = with types; attrsOf (submoduleForDefinition "isindir.github.com.v1alpha3.SopsSecret" "sopssecrets" "SopsSecret" "isindir.github.com" "v1alpha3");
      default = {};
    };
    sopsSecrets = mkOption {
      type = with types; attrsOf (submoduleForDefinition "isindir.github.com.v1alpha3.SopsSecret" "sopssecrets" "SopsSecret" "isindir.github.com" "v1alpha3");
      default = {};
    };
  };

  config = {
    types = [
      {
        name = "sopssecrets";
        group = "isindir.github.com";
        version = "v1alpha3";
        kind = "SopsSecret";
        attrName = "sopsSecrets";
      }
    ];

    resources = {
      "isindir.github.com"."v1alpha3"."SopsSecret" = lib.mkAliasDefinitions options.resources.sopsSecrets;
    };
  };
}

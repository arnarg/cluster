# This file was generated with nixidy CRD generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:
with lib; let
  hasAttrNotNull = attr: set: hasAttr attr set && set.${attr} != null;

  attrsToList = values:
    if values != null
    then
      sort (
        a: b:
          if (hasAttrNotNull "_priority" a && hasAttrNotNull "_priority" b)
          then a._priority < b._priority
          else false
      ) (mapAttrsToList (n: v: v) values)
    else values;

  getDefaults = resource: group: version: kind:
    catAttrs "default" (filter (
        default:
          (default.resource == null || default.resource == resource)
          && (default.group == null || default.group == group)
          && (default.version == null || default.version == version)
          && (default.kind == null || default.kind == kind)
      )
      config.defaults);

  types =
    lib.types
    // rec {
      str = mkOptionType {
        name = "str";
        description = "string";
        check = isString;
        merge = mergeEqualOption;
      };

      # Either value of type `finalType` or `coercedType`, the latter is
      # converted to `finalType` using `coerceFunc`.
      coercedTo = coercedType: coerceFunc: finalType:
        mkOptionType rec {
          inherit (finalType) getSubOptions getSubModules;

          name = "coercedTo";
          description = "${finalType.description} or ${coercedType.description}";
          check = x: finalType.check x || coercedType.check x;
          merge = loc: defs: let
            coerceVal = val:
              if finalType.check val
              then val
              else let
                coerced = coerceFunc val;
              in
                assert finalType.check coerced; coerced;
          in
            finalType.merge loc (map (def: def // {value = coerceVal def.value;}) defs);
          substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
          typeMerge = t1: t2: null;
          functor = (defaultFunctor name) // {wrapped = finalType;};
        };
    };

  mkOptionDefault = mkOverride 1001;

  mergeValuesByKey = attrMergeKey: listMergeKeys: values:
    listToAttrs (imap0
      (i: value:
        nameValuePair (
          if hasAttr attrMergeKey value
          then
            if isAttrs value.${attrMergeKey}
            then toString value.${attrMergeKey}.content
            else (toString value.${attrMergeKey})
          else
            # generate merge key for list elements if it's not present
            "__kubenix_list_merge_key_"
            + (concatStringsSep "" (map (
                key:
                  if isAttrs value.${key}
                  then toString value.${key}.content
                  else (toString value.${key})
              )
              listMergeKeys))
        ) (value // {_priority = i;}))
      values);

  submoduleOf = ref:
    types.submodule ({name, ...}: {
      options = definitions."${ref}".options or {};
      config = definitions."${ref}".config or {};
    });

  globalSubmoduleOf = ref:
    types.submodule ({name, ...}: {
      options = config.definitions."${ref}".options or {};
      config = config.definitions."${ref}".config or {};
    });

  submoduleWithMergeOf = ref: mergeKey:
    types.submodule ({name, ...}: let
      convertName = name:
        if definitions."${ref}".options.${mergeKey}.type == types.int
        then toInt name
        else name;
    in {
      options =
        definitions."${ref}".options
        // {
          # position in original array
          _priority = mkOption {
            type = types.nullOr types.int;
            default = null;
          };
        };
      config =
        definitions."${ref}".config
        // {
          ${mergeKey} = mkOverride 1002 (
            # use name as mergeKey only if it is not coming from mergeValuesByKey
            if (!hasPrefix "__kubenix_list_merge_key_" name)
            then convertName name
            else null
          );
        };
    });

  submoduleForDefinition = ref: resource: kind: group: version: let
    apiVersion =
      if group == "core"
      then version
      else "${group}/${version}";
  in
    types.submodule ({name, ...}: {
      inherit (definitions."${ref}") options;

      imports = getDefaults resource group version kind;
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

  coerceAttrsOfSubmodulesToListByKey = ref: attrMergeKey: listMergeKeys: (
    types.coercedTo
    (types.listOf (submoduleOf ref))
    (mergeValuesByKey attrMergeKey listMergeKeys)
    (types.attrsOf (submoduleWithMergeOf ref attrMergeKey))
  );

  definitions = {
    "onepassword.com.v1.OnePasswordItem" = {
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
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "OnePasswordItemSpec defines the desired state of OnePasswordItem";
          type = types.nullOr (submoduleOf "onepassword.com.v1.OnePasswordItemSpec");
        };
        "status" = mkOption {
          description = "OnePasswordItemStatus defines the observed state of OnePasswordItem";
          type = types.nullOr (submoduleOf "onepassword.com.v1.OnePasswordItemStatus");
        };
        "type" = mkOption {
          description = "Kubernetes secret type. More info: https://kubernetes.io/docs/concepts/configuration/secret/#secret-types";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };
    };
    "onepassword.com.v1.OnePasswordItemSpec" = {
      options = {
        "itemPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "itemPath" = mkOverride 1002 null;
      };
    };
    "onepassword.com.v1.OnePasswordItemStatus" = {
      options = {
        "conditions" = mkOption {
          description = "";
          type = types.listOf (submoduleOf "onepassword.com.v1.OnePasswordItemStatusConditions");
        };
      };

      config = {};
    };
    "onepassword.com.v1.OnePasswordItemStatusConditions" = {
      options = {
        "lastTransitionTime" = mkOption {
          description = "Last time the condition transit from one status to another.";
          type = types.nullOr types.str;
        };
        "message" = mkOption {
          description = "Human-readable message indicating details about last transition.";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "Status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "Type of job condition, Completed.";
          type = types.str;
        };
      };

      config = {
        "lastTransitionTime" = mkOverride 1002 null;
        "message" = mkOverride 1002 null;
      };
    };
  };
in {
  # all resource versions
  options = {
    resources =
      {
        "onepassword.com"."v1"."OnePasswordItem" = mkOption {
          description = "OnePasswordItem is the Schema for the onepassworditems API";
          type = types.attrsOf (submoduleForDefinition "onepassword.com.v1.OnePasswordItem" "onepassworditems" "OnePasswordItem" "onepassword.com" "v1");
          default = {};
        };
      }
      // {
        "onePasswordItems" = mkOption {
          description = "OnePasswordItem is the Schema for the onepassworditems API";
          type = types.attrsOf (submoduleForDefinition "onepassword.com.v1.OnePasswordItem" "onepassworditems" "OnePasswordItem" "onepassword.com" "v1");
          default = {};
        };
      };
  };

  config = {
    # expose resource definitions
    inherit definitions;

    # register resource types
    types = [
      {
        name = "onepassworditems";
        group = "onepassword.com";
        version = "v1";
        kind = "OnePasswordItem";
        attrName = "onePasswordItems";
      }
    ];

    resources = {
      "onepassword.com"."v1"."OnePasswordItem" =
        mkAliasDefinitions options.resources."onePasswordItems";
    };

    defaults = [
      {
        group = "onepassword.com";
        version = "v1";
        kind = "OnePasswordItem";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}

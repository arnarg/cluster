# This file was generated with nixidy resource generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:

with lib;

let
  hasAttrNotNull = attr: set: hasAttr attr set && set.${attr} != null;

  attrsToList =
    values:
    if values != null then
      sort (
        a: b:
        if (hasAttrNotNull "_priority" a && hasAttrNotNull "_priority" b) then
          a._priority < b._priority
        else
          false
      ) (mapAttrsToList (n: v: v) values)
    else
      values;

  getDefaults =
    resource: group: version: kind:
    catAttrs "default" (
      filter (
        default:
        (default.resource == null || default.resource == resource)
        && (default.group == null || default.group == group)
        && (default.version == null || default.version == version)
        && (default.kind == null || default.kind == kind)
      ) config.defaults
    );

  types = lib.types // rec {
    str = mkOptionType {
      name = "str";
      description = "string";
      check = isString;
      merge = mergeEqualOption;
    };

    # Either value of type `finalType` or `coercedType`, the latter is
    # converted to `finalType` using `coerceFunc`.
    coercedTo =
      coercedType: coerceFunc: finalType:
      mkOptionType rec {
        inherit (finalType) getSubOptions getSubModules;

        name = "coercedTo";
        description = "${finalType.description} or ${coercedType.description}";
        check = x: finalType.check x || coercedType.check x;
        merge =
          loc: defs:
          let
            coerceVal =
              val:
              if finalType.check val then
                val
              else
                let
                  coerced = coerceFunc val;
                in
                assert finalType.check coerced;
                coerced;

          in
          finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
        substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
        typeMerge = t1: t2: null;
        functor = (defaultFunctor name) // {
          wrapped = finalType;
        };
      };
  };

  mkOptionDefault = mkOverride 1001;

  mergeValuesByKey =
    attrMergeKey: listMergeKeys: values:
    listToAttrs (
      imap0 (
        i: value:
        nameValuePair (
          if hasAttr attrMergeKey value then
            if isAttrs value.${attrMergeKey} then
              toString value.${attrMergeKey}.content
            else
              (toString value.${attrMergeKey})
          else
            # generate merge key for list elements if it's not present
            "__kubenix_list_merge_key_"
            + (concatStringsSep "" (
              map (
                key: if isAttrs value.${key} then toString value.${key}.content else (toString value.${key})
              ) listMergeKeys
            ))
        ) (value // { _priority = i; })
      ) values
    );

  submoduleOf =
    ref:
    types.submodule (
      { name, ... }:
      {
        options = definitions."${ref}".options or { };
        config = definitions."${ref}".config or { };
      }
    );

  globalSubmoduleOf =
    ref:
    types.submodule (
      { name, ... }:
      {
        options = config.definitions."${ref}".options or { };
        config = config.definitions."${ref}".config or { };
      }
    );

  submoduleWithMergeOf =
    ref: mergeKey:
    types.submodule (
      { name, ... }:
      let
        convertName =
          name: if definitions."${ref}".options.${mergeKey}.type == types.int then toInt name else name;
      in
      {
        options = definitions."${ref}".options // {
          # position in original array
          _priority = mkOption {
            type = types.nullOr types.int;
            default = null;
          };
        };
        config = definitions."${ref}".config // {
          ${mergeKey} = mkOverride 1002 (
            # use name as mergeKey only if it is not coming from mergeValuesByKey
            if (!hasPrefix "__kubenix_list_merge_key_" name) then convertName name else null
          );
        };
      }
    );

  submoduleForDefinition =
    ref: resource: kind: group: version:
    let
      apiVersion = if group == "core" then version else "${group}/${version}";
    in
    types.submodule (
      { name, ... }:
      {
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
      }
    );

  coerceAttrsOfSubmodulesToListByKey =
    ref: attrMergeKey: listMergeKeys:
    (types.coercedTo (types.listOf (submoduleOf ref)) (mergeValuesByKey attrMergeKey listMergeKeys) (
      types.attrsOf (submoduleWithMergeOf ref attrMergeKey)
    ));

  definitions = {
    "tailscale.com.v1alpha1.ProxyClass" = {

      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = (types.nullOr types.str);
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = (types.nullOr types.str);
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = (types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta"));
        };
        "spec" = mkOption {
          description = "Specification of the desired state of the ProxyClass resource.\nhttps://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status";
          type = (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpec");
        };
        "status" = mkOption {
          description = "Status of the ProxyClass. This is set and managed automatically.\nhttps://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassStatus"));
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpec" = {

      options = {
        "metrics" = mkOption {
          description = "Configuration for proxy metrics. Metrics are currently not supported\nfor egress proxies and for Ingress proxies that have been configured\nwith tailscale.com/experimental-forward-cluster-traffic-via-ingress\nannotation. Note that the metrics are currently considered unstable\nand will likely change in breaking ways in the future - we only\nrecommend that you use those for debugging purposes.";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecMetrics"));
        };
        "statefulSet" = mkOption {
          description = "Configuration parameters for the proxy's StatefulSet. Tailscale\nKubernetes operator deploys a StatefulSet for each of the user\nconfigured proxies (Tailscale Ingress, Tailscale Service, Connector).";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSet"));
        };
        "staticEndpoints" = mkOption {
          description = "Configuration for 'static endpoints' on proxies in order to facilitate\ndirect connections from other devices on the tailnet.\nSee https://tailscale.com/kb/1445/kubernetes-operator-customization#static-endpoints.";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStaticEndpoints"));
        };
        "tailscale" = mkOption {
          description = "TailscaleConfig contains options to configure the tailscale-specific\nparameters of proxies.";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecTailscale"));
        };
        "useLetsEncryptStagingEnvironment" = mkOption {
          description = "Set UseLetsEncryptStagingEnvironment to true to issue TLS\ncertificates for any HTTPS endpoints exposed to the tailnet from\nLetsEncrypt's staging environment.\nhttps://letsencrypt.org/docs/staging-environment/\nThis setting only affects Tailscale Ingress resources.\nBy default Ingress TLS certificates are issued from LetsEncrypt's\nproduction environment.\nChanging this setting true -> false, will result in any\nexisting certs being re-issued from the production environment.\nChanging this setting false (default) -> true, when certs have already\nbeen provisioned from production environment will NOT result in certs\nbeing re-issued from the staging environment before they need to be\nrenewed.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "metrics" = mkOverride 1002 null;
        "statefulSet" = mkOverride 1002 null;
        "staticEndpoints" = mkOverride 1002 null;
        "tailscale" = mkOverride 1002 null;
        "useLetsEncryptStagingEnvironment" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecMetrics" = {

      options = {
        "enable" = mkOption {
          description = "Setting enable to true will make the proxy serve Tailscale metrics\nat <pod-ip>:9002/metrics.\nA metrics Service named <proxy-statefulset>-metrics will also be created in the operator's namespace and will\nserve the metrics at <service-ip>:9002/metrics.\n\nIn 1.78.x and 1.80.x, this field also serves as the default value for\n.spec.statefulSet.pod.tailscaleContainer.debug.enable. From 1.82.0, both\nfields will independently default to false.\n\nDefaults to false.";
          type = types.bool;
        };
        "serviceMonitor" = mkOption {
          description = "Enable to create a Prometheus ServiceMonitor for scraping the proxy's Tailscale metrics.\nThe ServiceMonitor will select the metrics Service that gets created when metrics are enabled.\nThe ingested metrics for each Service monitor will have labels to identify the proxy:\nts_proxy_type: ingress_service|ingress_resource|connector|proxygroup\nts_proxy_parent_name: name of the parent resource (i.e name of the Connector, Tailscale Ingress, Tailscale Service or ProxyGroup)\nts_proxy_parent_namespace: namespace of the parent resource (if the parent resource is not cluster scoped)\njob: ts_<proxy type>_[<parent namespace>]_<parent_name>";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecMetricsServiceMonitor"));
        };
      };

      config = {
        "serviceMonitor" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecMetricsServiceMonitor" = {

      options = {
        "enable" = mkOption {
          description = "If Enable is set to true, a Prometheus ServiceMonitor will be created. Enable can only be set to true if metrics are enabled.";
          type = types.bool;
        };
        "labels" = mkOption {
          description = "Labels to add to the ServiceMonitor.\nLabels must be valid Kubernetes labels.\nhttps://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "labels" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSet" = {

      options = {
        "annotations" = mkOption {
          description = "Annotations that will be added to the StatefulSet created for the proxy.\nAny Annotations specified here will be merged with the default annotations\napplied to the StatefulSet by the Tailscale Kubernetes operator as\nwell as any other annotations that might have been applied by other\nactors.\nAnnotations must be valid Kubernetes annotations.\nhttps://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "labels" = mkOption {
          description = "Labels that will be added to the StatefulSet created for the proxy.\nAny labels specified here will be merged with the default labels\napplied to the StatefulSet by the Tailscale Kubernetes operator as\nwell as any other labels that might have been applied by other\nactors.\nLabel keys and values must be valid Kubernetes label keys and values.\nhttps://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "pod" = mkOption {
          description = "Configuration for the proxy Pod.";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPod"));
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "pod" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPod" = {

      options = {
        "affinity" = mkOption {
          description = "Proxy Pod's affinity rules.\nBy default, the Tailscale Kubernetes operator does not apply any affinity rules.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#affinity";
          type = (types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinity"));
        };
        "annotations" = mkOption {
          description = "Annotations that will be added to the proxy Pod.\nAny annotations specified here will be merged with the default\nannotations applied to the Pod by the Tailscale Kubernetes operator.\nAnnotations must be valid Kubernetes annotations.\nhttps://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "imagePullSecrets" = mkOption {
          description = "Proxy Pod's image pull Secrets.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#PodSpec";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodImagePullSecrets"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "labels" = mkOption {
          description = "Labels that will be added to the proxy Pod.\nAny labels specified here will be merged with the default labels\napplied to the Pod by the Tailscale Kubernetes operator.\nLabel keys and values must be valid Kubernetes label keys and values.\nhttps://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "nodeName" = mkOption {
          description = "Proxy Pod's node name.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#scheduling";
          type = (types.nullOr types.str);
        };
        "nodeSelector" = mkOption {
          description = "Proxy Pod's node selector.\nBy default Tailscale Kubernetes operator does not apply any node\nselector.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#scheduling";
          type = (types.nullOr (types.attrsOf types.str));
        };
        "priorityClassName" = mkOption {
          description = "PriorityClassName for the proxy Pod.\nBy default Tailscale Kubernetes operator does not apply any priority class.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#scheduling";
          type = (types.nullOr types.str);
        };
        "securityContext" = mkOption {
          description = "Proxy Pod's security context.\nBy default Tailscale Kubernetes operator does not apply any Pod\nsecurity context.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#security-context-2";
          type = (
            types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContext")
          );
        };
        "tailscaleContainer" = mkOption {
          description = "Configuration for the proxy container running tailscale.";
          type = (
            types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainer")
          );
        };
        "tailscaleInitContainer" = mkOption {
          description = "Configuration for the proxy init container that enables forwarding.\nNot valid to apply to ProxyGroups of type \"kube-apiserver\".";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainer"
            )
          );
        };
        "tolerations" = mkOption {
          description = "Proxy Pod's tolerations.\nBy default Tailscale Kubernetes operator does not apply any\ntolerations.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#scheduling";
          type = (
            types.nullOr (
              types.listOf (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTolerations")
            )
          );
        };
        "topologySpreadConstraints" = mkOption {
          description = "Proxy Pod's topology spread constraints.\nBy default Tailscale Kubernetes operator does not apply any topology spread constraints.\nhttps://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTopologySpreadConstraints"
              )
            )
          );
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "nodeName" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
        "tailscaleContainer" = mkOverride 1002 null;
        "tailscaleInitContainer" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "topologySpreadConstraints" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "Describes node affinity scheduling rules for the pod.";
          type = (
            types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinity")
          );
        };
        "podAffinity" = mkOption {
          description = "Describes pod affinity scheduling rules (e.g. co-locate this pod in the same node, zone, etc. as some other pod(s)).";
          type = (
            types.nullOr (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinity")
          );
        };
        "podAntiAffinity" = mkOption {
          description = "Describes pod anti-affinity scheduling rules (e.g. avoid putting this pod in the same node, zone, etc. as some other pod(s)).";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinity"
            )
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "The scheduler will prefer to schedule pods to nodes that satisfy\nthe affinity expressions specified by this field, but it may choose\na node that violates one or more of the expressions. The node that is\nmost preferred is the one with the greatest sum of weights, i.e.\nfor each node that meets all of the scheduling requirements (resource\nrequest, requiredDuringScheduling affinity expressions, etc.),\ncompute a sum by iterating through the elements of this field and adding\n\"weight\" to the sum if the node matches the corresponding matchExpressions; the\nnode(s) with the highest sum are the most preferred.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
              )
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "If the affinity requirements specified by this field are not met at\nscheduling time, the pod will not be scheduled onto the node.\nIf the affinity requirements specified by this field cease to be met\nat some point during pod execution (e.g. due to an update), the system\nmay or may not try to eventually evict the pod from its node.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "A node selector term, associated with the corresponding weight.";
            type = (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference"
            );
          };
          "weight" = mkOption {
            description = "Weight associated with matching the corresponding nodeSelectorTerm, in the range 1-100.";
            type = types.int;
          };
        };

        config = { };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "A list of node selector requirements by node's labels.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
                )
              )
            );
          };
          "matchFields" = mkOption {
            description = "A list of node selector requirements by node's fields.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
                )
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "The label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
            type = types.str;
          };
          "values" = mkOption {
            description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "The label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
            type = types.str;
          };
          "values" = mkOption {
            description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "Required. A list of node selector terms. The terms are ORed.";
            type = (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
              )
            );
          };
        };

        config = { };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "A list of node selector requirements by node's labels.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
                )
              )
            );
          };
          "matchFields" = mkOption {
            description = "A list of node selector requirements by node's fields.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
                )
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "The label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
            type = types.str;
          };
          "values" = mkOption {
            description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "The label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "Represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.";
            type = types.str;
          };
          "values" = mkOption {
            description = "An array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. If the operator is Gt or Lt, the values\narray must have a single element, which will be interpreted as an integer.\nThis array is replaced during a strategic merge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "The scheduler will prefer to schedule pods to nodes that satisfy\nthe affinity expressions specified by this field, but it may choose\na node that violates one or more of the expressions. The node that is\nmost preferred is the one with the greatest sum of weights, i.e.\nfor each node that meets all of the scheduling requirements (resource\nrequest, requiredDuringScheduling affinity expressions, etc.),\ncompute a sum by iterating through the elements of this field and adding\n\"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the\nnode(s) with the highest sum are the most preferred.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
              )
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "If the affinity requirements specified by this field are not met at\nscheduling time, the pod will not be scheduled onto the node.\nIf the affinity requirements specified by this field cease to be met\nat some point during pod execution (e.g. due to a pod label update), the\nsystem may or may not try to eventually evict the pod from its node.\nWhen there are multiple elements, the lists of nodes corresponding to each\npodAffinityTerm are intersected, i.e. all terms must be satisfied.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
              )
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "Required. A pod affinity term, associated with the corresponding weight.";
            type = (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm"
            );
          };
          "weight" = mkOption {
            description = "weight associated with matching the corresponding podAffinityTerm,\nin the range 1-100.";
            type = types.int;
          };
        };

        config = { };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
              )
            );
          };
          "matchLabelKeys" = mkOption {
            description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "mismatchLabelKeys" = mkOption {
            description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "namespaceSelector" = mkOption {
            description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
              )
            );
          };
          "namespaces" = mkOption {
            description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
            type = (types.nullOr (types.listOf types.str));
          };
          "topologyKey" = mkOption {
            description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
              )
            );
          };
          "matchLabelKeys" = mkOption {
            description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "mismatchLabelKeys" = mkOption {
            description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "namespaceSelector" = mkOption {
            description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
              )
            );
          };
          "namespaces" = mkOption {
            description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
            type = (types.nullOr (types.listOf types.str));
          };
          "topologyKey" = mkOption {
            description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "The scheduler will prefer to schedule pods to nodes that satisfy\nthe anti-affinity expressions specified by this field, but it may choose\na node that violates one or more of the expressions. The node that is\nmost preferred is the one with the greatest sum of weights, i.e.\nfor each node that meets all of the scheduling requirements (resource\nrequest, requiredDuringScheduling anti-affinity expressions, etc.),\ncompute a sum by iterating through the elements of this field and adding\n\"weight\" to the sum if the node has pods which matches the corresponding podAffinityTerm; the\nnode(s) with the highest sum are the most preferred.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
              )
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "If the anti-affinity requirements specified by this field are not met at\nscheduling time, the pod will not be scheduled onto the node.\nIf the anti-affinity requirements specified by this field cease to be met\nat some point during pod execution (e.g. due to a pod label update), the\nsystem may or may not try to eventually evict the pod from its node.\nWhen there are multiple elements, the lists of nodes corresponding to each\npodAffinityTerm are intersected, i.e. all terms must be satisfied.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
              )
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "Required. A pod affinity term, associated with the corresponding weight.";
            type = (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm"
            );
          };
          "weight" = mkOption {
            description = "weight associated with matching the corresponding podAffinityTerm,\nin the range 1-100.";
            type = types.int;
          };
        };

        config = { };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
              )
            );
          };
          "matchLabelKeys" = mkOption {
            description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "mismatchLabelKeys" = mkOption {
            description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "namespaceSelector" = mkOption {
            description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
              )
            );
          };
          "namespaces" = mkOption {
            description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
            type = (types.nullOr (types.listOf types.str));
          };
          "topologyKey" = mkOption {
            description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "A label query over a set of resources, in this case pods.\nIf it's null, this PodAffinityTerm matches with no Pods.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
              )
            );
          };
          "matchLabelKeys" = mkOption {
            description = "MatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key in (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both matchLabelKeys and labelSelector.\nAlso, matchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "mismatchLabelKeys" = mkOption {
            description = "MismatchLabelKeys is a set of pod label keys to select which pods will\nbe taken into consideration. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are merged with `labelSelector` as `key notin (value)`\nto select the group of existing pods which pods will be taken into consideration\nfor the incoming pod's pod (anti) affinity. Keys that don't exist in the incoming\npod labels will be ignored. The default value is empty.\nThe same key is forbidden to exist in both mismatchLabelKeys and labelSelector.\nAlso, mismatchLabelKeys cannot be set when labelSelector isn't set.\nThis is a beta field and requires enabling MatchLabelKeysInPodAffinity feature gate (enabled by default).";
            type = (types.nullOr (types.listOf types.str));
          };
          "namespaceSelector" = mkOption {
            description = "A label query over the set of namespaces that the term applies to.\nThe term is applied to the union of the namespaces selected by this field\nand the ones listed in the namespaces field.\nnull selector and null or empty namespaces list means \"this pod's namespace\".\nAn empty selector ({}) matches all namespaces.";
            type = (
              types.nullOr (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
              )
            );
          };
          "namespaces" = mkOption {
            description = "namespaces specifies a static list of namespace names that the term applies to.\nThe term is applied to the union of the namespaces listed in this field\nand the ones selected by namespaceSelector.\nnull or empty namespaces list and null namespaceSelector means \"this pod's namespace\".";
            type = (types.nullOr (types.listOf types.str));
          };
          "topologyKey" = mkOption {
            description = "This pod should be co-located (affinity) or not co-located (anti-affinity) with the pods matching\nthe labelSelector in the specified namespaces, where co-located is defined as running on a node\nwhose value of the label with key topologyKey matches that of any node on which any of the\nselected pods is running.\nEmpty topologyKey is not allowed.";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
            type = (
              types.nullOr (
                types.listOf (
                  submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
                )
              )
            );
          };
          "matchLabels" = mkOption {
            description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
            type = (types.nullOr (types.attrsOf types.str));
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "Name of the referent.\nThis field is effectively required, but due to backwards compatibility is\nallowed to be empty. Instances of this type with an empty value here are\nalmost certainly wrong.\nMore info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by the containers in this pod.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextAppArmorProfile"
            )
          );
        };
        "fsGroup" = mkOption {
          description = "A special supplemental group that applies to all containers in a pod.\nSome volume types allow the Kubelet to change the ownership of that volume\nto be owned by the pod:\n\n1. The owning GID will be the FSGroup\n2. The setgid bit is set (new files created in the volume will be owned by FSGroup)\n3. The permission bits are OR'd with rw-rw----\n\nIf unset, the Kubelet will not modify the ownership and permissions of any volume.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "fsGroupChangePolicy" = mkOption {
          description = "fsGroupChangePolicy defines behavior of changing ownership and permission of the volume\nbefore being exposed inside Pod. This field will only apply to\nvolume types which support fsGroup based ownership(and permissions).\nIt will have no effect on ephemeral volume types such as: secret, configmaps\nand emptydir.\nValid values are \"OnRootMismatch\" and \"Always\". If not specified, \"Always\" is used.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.str);
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in SecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence\nfor that container.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in SecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = (types.nullOr types.bool);
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in SecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence\nfor that container.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "seLinuxChangePolicy" = mkOption {
          description = "seLinuxChangePolicy defines how the container's SELinux label is applied to all volumes used by the Pod.\nIt has no effect on nodes that do not support SELinux or to volumes does not support SELinux.\nValid values are \"MountOption\" and \"Recursive\".\n\n\"Recursive\" means relabeling of all files on all Pod volumes by the container runtime.\nThis may be slow for large volumes, but allows mixing privileged and unprivileged Pods sharing the same volume on the same node.\n\n\"MountOption\" mounts all eligible Pod volumes with `-o context` mount option.\nThis requires all Pods that share the same volume to use the same SELinux label.\nIt is not possible to share the same volume among privileged and unprivileged Pods.\nEligible volumes are in-tree FibreChannel and iSCSI volumes, and all CSI volumes\nwhose CSI driver announces SELinux support by setting spec.seLinuxMount: true in their\nCSIDriver instance. Other volumes are always re-labelled recursively.\n\"MountOption\" value is allowed only when SELinuxMount feature gate is enabled.\n\nIf not specified and SELinuxMount feature gate is enabled, \"MountOption\" is used.\nIf not specified and SELinuxMount feature gate is disabled, \"MountOption\" is used for ReadWriteOncePod volumes\nand \"Recursive\" for all other volumes.\n\nThis field affects only Pods that have SELinux label set, either in PodSecurityContext or in SecurityContext of all containers.\n\nAll Pods that use the same volume should use the same seLinuxChangePolicy, otherwise some pods can get stuck in ContainerCreating state.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.str);
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to all containers.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in SecurityContext.  If set in\nboth SecurityContext and PodSecurityContext, the value specified in SecurityContext\ntakes precedence for that container.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextSeLinuxOptions"
            )
          );
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by the containers in this pod.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextSeccompProfile"
            )
          );
        };
        "supplementalGroups" = mkOption {
          description = "A list of groups applied to the first process run in each container, in\naddition to the container's primary GID and fsGroup (if specified).  If\nthe SupplementalGroupsPolicy feature is enabled, the\nsupplementalGroupsPolicy field determines whether these are in addition\nto or instead of any group memberships defined in the container image.\nIf unspecified, no additional groups are added, though group memberships\ndefined in the container image may still be used, depending on the\nsupplementalGroupsPolicy field.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr (types.listOf types.int));
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "Defines how supplemental groups of the first container processes are calculated.\nValid values are \"Merge\" and \"Strict\". If not specified, \"Merge\" is used.\n(Alpha) Using the field requires the SupplementalGroupsPolicy feature gate to be enabled\nand the container runtime must implement support for this feature.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.str);
        };
        "sysctls" = mkOption {
          description = "Sysctls hold a list of namespaced sysctls used for the pod. Pods with unsupported\nsysctls (by the container runtime) might fail to launch.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextSysctls"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options within a container's SecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextWindowsOptions"
            )
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "Level is SELinux level label that applies to the container.";
          type = (types.nullOr types.str);
        };
        "role" = mkOption {
          description = "Role is a SELinux role label that applies to the container.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "Type is a SELinux type label that applies to the container.";
          type = (types.nullOr types.str);
        };
        "user" = mkOption {
          description = "User is a SELinux user label that applies to the container.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
          type = (types.nullOr types.str);
        };
        "type" = mkOption {
          description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "Name of a property to set";
          type = types.str;
        };
        "value" = mkOption {
          description = "Value of a property to set";
          type = types.str;
        };
      };

      config = { };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
          type = (types.nullOr types.str);
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
          type = (types.nullOr types.str);
        };
        "hostProcess" = mkOption {
          description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
          type = (types.nullOr types.bool);
        };
        "runAsUserName" = mkOption {
          description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainer" = {

      options = {
        "debug" = mkOption {
          description = "Configuration for enabling extra debug information in the container.\nNot recommended for production use.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerDebug"
            )
          );
        };
        "env" = mkOption {
          description = "List of environment variables to set in the container.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#environment-variables\nNote that environment variables provided here will take precedence\nover Tailscale-specific environment variables set by the operator,\nhowever running proxies with custom values for Tailscale environment\nvariables (i.e TS_USERSPACE) is not recommended and might break in\nthe future.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerEnv"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "image" = mkOption {
          description = "Container image name. By default images are pulled from docker.io/tailscale,\nbut the official images are also available at ghcr.io/tailscale.\n\nFor all uses except on ProxyGroups of type \"kube-apiserver\", this image must\nbe either tailscale/tailscale, or an equivalent mirror of that image.\nTo apply to ProxyGroups of type \"kube-apiserver\", this image must be\ntailscale/k8s-proxy or a mirror of that image.\n\nFor \"tailscale/tailscale\"-based proxies, specifying image name here will\noverride any proxy image values specified via the Kubernetes operator's\nHelm chart values or PROXY_IMAGE env var in the operator Deployment.\nFor \"tailscale/k8s-proxy\"-based proxies, there is currently no way to\nconfigure your own default, and this field is the only way to use a\ncustom image.\n\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#image";
          type = (types.nullOr types.str);
        };
        "imagePullPolicy" = mkOption {
          description = "Image pull policy. One of Always, Never, IfNotPresent. Defaults to Always.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#image";
          type = (types.nullOr types.str);
        };
        "resources" = mkOption {
          description = "Container resource requirements.\nBy default Tailscale Kubernetes operator does not apply any resource\nrequirements. The amount of resources required wil depend on the\namount of resources the operator needs to parse, usage patterns and\ncluster size.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#resources";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerResources"
            )
          );
        };
        "securityContext" = mkOption {
          description = "Container security context.\nSecurity context specified here will override the security context set by the operator.\nBy default the operator sets the Tailscale container and the Tailscale init container to privileged\nfor proxies created for Tailscale ingress and egress Service, Connector and ProxyGroup.\nYou can reduce the permissions of the Tailscale container to cap NET_ADMIN by\ninstalling device plugin in your cluster and configuring the proxies tun device to be created\nby the device plugin, see  https://github.com/tailscale/tailscale/issues/10814#issuecomment-2479977752\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#security-context";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContext"
            )
          );
        };
      };

      config = {
        "debug" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerDebug" = {

      options = {
        "enable" = mkOption {
          description = "Enable tailscaled's HTTP pprof endpoints at <pod-ip>:9001/debug/pprof/\nand internal debug metrics endpoint at <pod-ip>:9001/debug/metrics, where\n9001 is a container port named \"debug\". The endpoints and their responses\nmay change in backwards incompatible ways in the future, and should not\nbe considered stable.\n\nIn 1.78.x and 1.80.x, this setting will default to the value of\n.spec.metrics.enable, and requests to the \"metrics\" port matching the\nmux pattern /debug/ will be forwarded to the \"debug\" port. In 1.82.x,\nthis setting will default to false, and no requests will be proxied.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "enable" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerEnv" = {

      options = {
        "name" = mkOption {
          description = "Name of the environment variable. Must be a C_IDENTIFIER.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Variable references $(VAR_NAME) are expanded using the previously defined\n environment variables in the container and any service environment\nvariables. If a variable cannot be resolved, the reference in the input\nstring will be unchanged. Double $$ are reduced to a single $, which\nallows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never\nbe expanded, regardless of whether the variable exists or not. Defaults\nto \"\".";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "value" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerResources" = {

      options = {
        "claims" = mkOption {
          description = "Claims lists the names of resources, defined in spec.resourceClaims,\nthat are used by this container.\n\nThis is an alpha field and requires enabling the\nDynamicResourceAllocation feature gate.\n\nThis field is immutable. It can only be set for containers.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerResourcesClaims"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "Limits describes the maximum amount of compute resources allowed.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = (types.nullOr (types.attrsOf (types.either types.int types.str)));
        };
        "requests" = mkOption {
          description = "Requests describes the minimum amount of compute resources required.\nIf Requests is omitted for a container, it defaults to Limits if that is explicitly specified,\notherwise to an implementation-defined value. Requests cannot exceed Limits.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = (types.nullOr (types.attrsOf (types.either types.int types.str)));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerResourcesClaims" = {

      options = {
        "name" = mkOption {
          description = "Name must match the name of one entry in pod.spec.resourceClaims of\nthe Pod where this field is used. It makes that resource available\ninside a container.";
          type = types.str;
        };
        "request" = mkOption {
          description = "Request is the name chosen for a request in the referenced claim.\nIf empty, everything from the claim is made available, otherwise\nonly the result of this request.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "AllowPrivilegeEscalation controls whether a process can gain more\nprivileges than its parent process. This bool directly controls if\nthe no_new_privs flag will be set on the container process.\nAllowPrivilegeEscalation is true always when the container is:\n1) run as Privileged\n2) has CAP_SYS_ADMIN\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.bool);
        };
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by this container. If set, this profile\noverrides the pod's appArmorProfile.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextAppArmorProfile"
            )
          );
        };
        "capabilities" = mkOption {
          description = "The capabilities to add/drop when running containers.\nDefaults to the default set of capabilities granted by the container runtime.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextCapabilities"
            )
          );
        };
        "privileged" = mkOption {
          description = "Run container in privileged mode.\nProcesses in privileged containers are essentially equivalent to root on the host.\nDefaults to false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.bool);
        };
        "procMount" = mkOption {
          description = "procMount denotes the type of proc mount to use for the containers.\nThe default value is Default which uses the container runtime defaults for\nreadonly paths and masked paths.\nThis requires the ProcMountType feature flag to be enabled.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.str);
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "Whether this container has a read-only root filesystem.\nDefault is false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.bool);
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = (types.nullOr types.bool);
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to the container.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextSeLinuxOptions"
            )
          );
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by this container. If seccomp options are\nprovided at both the pod & container level, the container options\noverride the pod options.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextSeccompProfile"
            )
          );
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options from the PodSecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextWindowsOptions"
            )
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextAppArmorProfile" =
      {

        options = {
          "localhostProfile" = mkOption {
            description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
            type = (types.nullOr types.str);
          };
          "type" = mkOption {
            description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
            type = types.str;
          };
        };

        config = {
          "localhostProfile" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextCapabilities" =
      {

        options = {
          "add" = mkOption {
            description = "Added capabilities";
            type = (types.nullOr (types.listOf types.str));
          };
          "drop" = mkOption {
            description = "Removed capabilities";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "add" = mkOverride 1002 null;
          "drop" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextSeLinuxOptions" =
      {

        options = {
          "level" = mkOption {
            description = "Level is SELinux level label that applies to the container.";
            type = (types.nullOr types.str);
          };
          "role" = mkOption {
            description = "Role is a SELinux role label that applies to the container.";
            type = (types.nullOr types.str);
          };
          "type" = mkOption {
            description = "Type is a SELinux type label that applies to the container.";
            type = (types.nullOr types.str);
          };
          "user" = mkOption {
            description = "User is a SELinux user label that applies to the container.";
            type = (types.nullOr types.str);
          };
        };

        config = {
          "level" = mkOverride 1002 null;
          "role" = mkOverride 1002 null;
          "type" = mkOverride 1002 null;
          "user" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextSeccompProfile" =
      {

        options = {
          "localhostProfile" = mkOption {
            description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
            type = (types.nullOr types.str);
          };
          "type" = mkOption {
            description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
            type = types.str;
          };
        };

        config = {
          "localhostProfile" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleContainerSecurityContextWindowsOptions" =
      {

        options = {
          "gmsaCredentialSpec" = mkOption {
            description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
            type = (types.nullOr types.str);
          };
          "gmsaCredentialSpecName" = mkOption {
            description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
            type = (types.nullOr types.str);
          };
          "hostProcess" = mkOption {
            description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
            type = (types.nullOr types.bool);
          };
          "runAsUserName" = mkOption {
            description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
            type = (types.nullOr types.str);
          };
        };

        config = {
          "gmsaCredentialSpec" = mkOverride 1002 null;
          "gmsaCredentialSpecName" = mkOverride 1002 null;
          "hostProcess" = mkOverride 1002 null;
          "runAsUserName" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainer" = {

      options = {
        "debug" = mkOption {
          description = "Configuration for enabling extra debug information in the container.\nNot recommended for production use.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerDebug"
            )
          );
        };
        "env" = mkOption {
          description = "List of environment variables to set in the container.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#environment-variables\nNote that environment variables provided here will take precedence\nover Tailscale-specific environment variables set by the operator,\nhowever running proxies with custom values for Tailscale environment\nvariables (i.e TS_USERSPACE) is not recommended and might break in\nthe future.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerEnv"
                "name"
                [ ]
            )
          );
          apply = attrsToList;
        };
        "image" = mkOption {
          description = "Container image name. By default images are pulled from docker.io/tailscale,\nbut the official images are also available at ghcr.io/tailscale.\n\nFor all uses except on ProxyGroups of type \"kube-apiserver\", this image must\nbe either tailscale/tailscale, or an equivalent mirror of that image.\nTo apply to ProxyGroups of type \"kube-apiserver\", this image must be\ntailscale/k8s-proxy or a mirror of that image.\n\nFor \"tailscale/tailscale\"-based proxies, specifying image name here will\noverride any proxy image values specified via the Kubernetes operator's\nHelm chart values or PROXY_IMAGE env var in the operator Deployment.\nFor \"tailscale/k8s-proxy\"-based proxies, there is currently no way to\nconfigure your own default, and this field is the only way to use a\ncustom image.\n\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#image";
          type = (types.nullOr types.str);
        };
        "imagePullPolicy" = mkOption {
          description = "Image pull policy. One of Always, Never, IfNotPresent. Defaults to Always.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#image";
          type = (types.nullOr types.str);
        };
        "resources" = mkOption {
          description = "Container resource requirements.\nBy default Tailscale Kubernetes operator does not apply any resource\nrequirements. The amount of resources required wil depend on the\namount of resources the operator needs to parse, usage patterns and\ncluster size.\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#resources";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerResources"
            )
          );
        };
        "securityContext" = mkOption {
          description = "Container security context.\nSecurity context specified here will override the security context set by the operator.\nBy default the operator sets the Tailscale container and the Tailscale init container to privileged\nfor proxies created for Tailscale ingress and egress Service, Connector and ProxyGroup.\nYou can reduce the permissions of the Tailscale container to cap NET_ADMIN by\ninstalling device plugin in your cluster and configuring the proxies tun device to be created\nby the device plugin, see  https://github.com/tailscale/tailscale/issues/10814#issuecomment-2479977752\nhttps://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#security-context";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContext"
            )
          );
        };
      };

      config = {
        "debug" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "securityContext" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerDebug" = {

      options = {
        "enable" = mkOption {
          description = "Enable tailscaled's HTTP pprof endpoints at <pod-ip>:9001/debug/pprof/\nand internal debug metrics endpoint at <pod-ip>:9001/debug/metrics, where\n9001 is a container port named \"debug\". The endpoints and their responses\nmay change in backwards incompatible ways in the future, and should not\nbe considered stable.\n\nIn 1.78.x and 1.80.x, this setting will default to the value of\n.spec.metrics.enable, and requests to the \"metrics\" port matching the\nmux pattern /debug/ will be forwarded to the \"debug\" port. In 1.82.x,\nthis setting will default to false, and no requests will be proxied.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "enable" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerEnv" = {

      options = {
        "name" = mkOption {
          description = "Name of the environment variable. Must be a C_IDENTIFIER.";
          type = types.str;
        };
        "value" = mkOption {
          description = "Variable references $(VAR_NAME) are expanded using the previously defined\n environment variables in the container and any service environment\nvariables. If a variable cannot be resolved, the reference in the input\nstring will be unchanged. Double $$ are reduced to a single $, which\nallows for escaping the $(VAR_NAME) syntax: i.e. \"$$(VAR_NAME)\" will\nproduce the string literal \"$(VAR_NAME)\". Escaped references will never\nbe expanded, regardless of whether the variable exists or not. Defaults\nto \"\".";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "value" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerResources" = {

      options = {
        "claims" = mkOption {
          description = "Claims lists the names of resources, defined in spec.resourceClaims,\nthat are used by this container.\n\nThis is an alpha field and requires enabling the\nDynamicResourceAllocation feature gate.\n\nThis field is immutable. It can only be set for containers.";
          type = (
            types.nullOr (
              coerceAttrsOfSubmodulesToListByKey
                "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerResourcesClaims"
                "name"
                [ "name" ]
            )
          );
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "Limits describes the maximum amount of compute resources allowed.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = (types.nullOr (types.attrsOf (types.either types.int types.str)));
        };
        "requests" = mkOption {
          description = "Requests describes the minimum amount of compute resources required.\nIf Requests is omitted for a container, it defaults to Limits if that is explicitly specified,\notherwise to an implementation-defined value. Requests cannot exceed Limits.\nMore info: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/";
          type = (types.nullOr (types.attrsOf (types.either types.int types.str)));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerResourcesClaims" = {

      options = {
        "name" = mkOption {
          description = "Name must match the name of one entry in pod.spec.resourceClaims of\nthe Pod where this field is used. It makes that resource available\ninside a container.";
          type = types.str;
        };
        "request" = mkOption {
          description = "Request is the name chosen for a request in the referenced claim.\nIf empty, everything from the claim is made available, otherwise\nonly the result of this request.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "AllowPrivilegeEscalation controls whether a process can gain more\nprivileges than its parent process. This bool directly controls if\nthe no_new_privs flag will be set on the container process.\nAllowPrivilegeEscalation is true always when the container is:\n1) run as Privileged\n2) has CAP_SYS_ADMIN\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.bool);
        };
        "appArmorProfile" = mkOption {
          description = "appArmorProfile is the AppArmor options to use by this container. If set, this profile\noverrides the pod's appArmorProfile.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextAppArmorProfile"
            )
          );
        };
        "capabilities" = mkOption {
          description = "The capabilities to add/drop when running containers.\nDefaults to the default set of capabilities granted by the container runtime.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextCapabilities"
            )
          );
        };
        "privileged" = mkOption {
          description = "Run container in privileged mode.\nProcesses in privileged containers are essentially equivalent to root on the host.\nDefaults to false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.bool);
        };
        "procMount" = mkOption {
          description = "procMount denotes the type of proc mount to use for the containers.\nThe default value is Default which uses the container runtime defaults for\nreadonly paths and masked paths.\nThis requires the ProcMountType feature flag to be enabled.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.str);
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "Whether this container has a read-only root filesystem.\nDefault is false.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.bool);
        };
        "runAsGroup" = mkOption {
          description = "The GID to run the entrypoint of the container process.\nUses runtime default if unset.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "runAsNonRoot" = mkOption {
          description = "Indicates that the container must run as a non-root user.\nIf true, the Kubelet will validate the image at runtime to ensure that it\ndoes not run as UID 0 (root) and fail to start the container if it does.\nIf unset or false, no such validation will be performed.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
          type = (types.nullOr types.bool);
        };
        "runAsUser" = mkOption {
          description = "The UID to run the entrypoint of the container process.\nDefaults to user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (types.nullOr types.int);
        };
        "seLinuxOptions" = mkOption {
          description = "The SELinux context to be applied to the container.\nIf unspecified, the container runtime will allocate a random SELinux context for each\ncontainer.  May also be set in PodSecurityContext.  If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextSeLinuxOptions"
            )
          );
        };
        "seccompProfile" = mkOption {
          description = "The seccomp options to use by this container. If seccomp options are\nprovided at both the pod & container level, the container options\noverride the pod options.\nNote that this field cannot be set when spec.os.name is windows.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextSeccompProfile"
            )
          );
        };
        "windowsOptions" = mkOption {
          description = "The Windows specific settings applied to all containers.\nIf unspecified, the options from the PodSecurityContext will be used.\nIf set in both SecurityContext and PodSecurityContext, the value specified in SecurityContext takes precedence.\nNote that this field cannot be set when spec.os.name is linux.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextWindowsOptions"
            )
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextAppArmorProfile" =
      {

        options = {
          "localhostProfile" = mkOption {
            description = "localhostProfile indicates a profile loaded on the node that should be used.\nThe profile must be preconfigured on the node to work.\nMust match the loaded name of the profile.\nMust be set if and only if type is \"Localhost\".";
            type = (types.nullOr types.str);
          };
          "type" = mkOption {
            description = "type indicates which kind of AppArmor profile will be applied.\nValid options are:\n  Localhost - a profile pre-loaded on the node.\n  RuntimeDefault - the container runtime's default profile.\n  Unconfined - no AppArmor enforcement.";
            type = types.str;
          };
        };

        config = {
          "localhostProfile" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextCapabilities" =
      {

        options = {
          "add" = mkOption {
            description = "Added capabilities";
            type = (types.nullOr (types.listOf types.str));
          };
          "drop" = mkOption {
            description = "Removed capabilities";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "add" = mkOverride 1002 null;
          "drop" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextSeLinuxOptions" =
      {

        options = {
          "level" = mkOption {
            description = "Level is SELinux level label that applies to the container.";
            type = (types.nullOr types.str);
          };
          "role" = mkOption {
            description = "Role is a SELinux role label that applies to the container.";
            type = (types.nullOr types.str);
          };
          "type" = mkOption {
            description = "Type is a SELinux type label that applies to the container.";
            type = (types.nullOr types.str);
          };
          "user" = mkOption {
            description = "User is a SELinux user label that applies to the container.";
            type = (types.nullOr types.str);
          };
        };

        config = {
          "level" = mkOverride 1002 null;
          "role" = mkOverride 1002 null;
          "type" = mkOverride 1002 null;
          "user" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextSeccompProfile" =
      {

        options = {
          "localhostProfile" = mkOption {
            description = "localhostProfile indicates a profile defined in a file on the node should be used.\nThe profile must be preconfigured on the node to work.\nMust be a descending path, relative to the kubelet's configured seccomp profile location.\nMust be set if type is \"Localhost\". Must NOT be set for any other type.";
            type = (types.nullOr types.str);
          };
          "type" = mkOption {
            description = "type indicates which kind of seccomp profile will be applied.\nValid options are:\n\nLocalhost - a profile defined in a file on the node should be used.\nRuntimeDefault - the container runtime default profile should be used.\nUnconfined - no profile should be applied.";
            type = types.str;
          };
        };

        config = {
          "localhostProfile" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTailscaleInitContainerSecurityContextWindowsOptions" =
      {

        options = {
          "gmsaCredentialSpec" = mkOption {
            description = "GMSACredentialSpec is where the GMSA admission webhook\n(https://github.com/kubernetes-sigs/windows-gmsa) inlines the contents of the\nGMSA credential spec named by the GMSACredentialSpecName field.";
            type = (types.nullOr types.str);
          };
          "gmsaCredentialSpecName" = mkOption {
            description = "GMSACredentialSpecName is the name of the GMSA credential spec to use.";
            type = (types.nullOr types.str);
          };
          "hostProcess" = mkOption {
            description = "HostProcess determines if a container should be run as a 'Host Process' container.\nAll of a Pod's containers must have the same effective HostProcess value\n(it is not allowed to have a mix of HostProcess containers and non-HostProcess containers).\nIn addition, if HostProcess is true then HostNetwork must also be set to true.";
            type = (types.nullOr types.bool);
          };
          "runAsUserName" = mkOption {
            description = "The UserName in Windows to run the entrypoint of the container process.\nDefaults to the user specified in image metadata if unspecified.\nMay also be set in PodSecurityContext. If set in both SecurityContext and\nPodSecurityContext, the value specified in SecurityContext takes precedence.";
            type = (types.nullOr types.str);
          };
        };

        config = {
          "gmsaCredentialSpec" = mkOverride 1002 null;
          "gmsaCredentialSpecName" = mkOverride 1002 null;
          "hostProcess" = mkOverride 1002 null;
          "runAsUserName" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTolerations" = {

      options = {
        "effect" = mkOption {
          description = "Effect indicates the taint effect to match. Empty means match all taint effects.\nWhen specified, allowed values are NoSchedule, PreferNoSchedule and NoExecute.";
          type = (types.nullOr types.str);
        };
        "key" = mkOption {
          description = "Key is the taint key that the toleration applies to. Empty means match all taint keys.\nIf the key is empty, operator must be Exists; this combination means to match all values and all keys.";
          type = (types.nullOr types.str);
        };
        "operator" = mkOption {
          description = "Operator represents a key's relationship to the value.\nValid operators are Exists and Equal. Defaults to Equal.\nExists is equivalent to wildcard for value, so that a pod can\ntolerate all taints of a particular category.";
          type = (types.nullOr types.str);
        };
        "tolerationSeconds" = mkOption {
          description = "TolerationSeconds represents the period of time the toleration (which must be\nof effect NoExecute, otherwise this field is ignored) tolerates the taint. By default,\nit is not set, which means tolerate the taint forever (do not evict). Zero and\nnegative values will be treated as 0 (evict immediately) by the system.";
          type = (types.nullOr types.int);
        };
        "value" = mkOption {
          description = "Value is the taint value the toleration matches to.\nIf the operator is Exists, the value should be empty, otherwise just a regular string.";
          type = (types.nullOr types.str);
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTopologySpreadConstraints" = {

      options = {
        "labelSelector" = mkOption {
          description = "LabelSelector is used to find matching pods.\nPods that match this label selector are counted to determine the number of pods\nin their corresponding topology domain.";
          type = (
            types.nullOr (
              submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTopologySpreadConstraintsLabelSelector"
            )
          );
        };
        "matchLabelKeys" = mkOption {
          description = "MatchLabelKeys is a set of pod label keys to select the pods over which\nspreading will be calculated. The keys are used to lookup values from the\nincoming pod labels, those key-value labels are ANDed with labelSelector\nto select the group of existing pods over which spreading will be calculated\nfor the incoming pod. The same key is forbidden to exist in both MatchLabelKeys and LabelSelector.\nMatchLabelKeys cannot be set when LabelSelector isn't set.\nKeys that don't exist in the incoming pod labels will\nbe ignored. A null or empty list means only match against labelSelector.\n\nThis is a beta field and requires the MatchLabelKeysInPodTopologySpread feature gate to be enabled (enabled by default).";
          type = (types.nullOr (types.listOf types.str));
        };
        "maxSkew" = mkOption {
          description = "MaxSkew describes the degree to which pods may be unevenly distributed.\nWhen `whenUnsatisfiable=DoNotSchedule`, it is the maximum permitted difference\nbetween the number of matching pods in the target topology and the global minimum.\nThe global minimum is the minimum number of matching pods in an eligible domain\nor zero if the number of eligible domains is less than MinDomains.\nFor example, in a 3-zone cluster, MaxSkew is set to 1, and pods with the same\nlabelSelector spread as 2/2/1:\nIn this case, the global minimum is 1.\n| zone1 | zone2 | zone3 |\n|  P P  |  P P  |   P   |\n- if MaxSkew is 1, incoming pod can only be scheduled to zone3 to become 2/2/2;\nscheduling it onto zone1(zone2) would make the ActualSkew(3-1) on zone1(zone2)\nviolate MaxSkew(1).\n- if MaxSkew is 2, incoming pod can be scheduled onto any zone.\nWhen `whenUnsatisfiable=ScheduleAnyway`, it is used to give higher precedence\nto topologies that satisfy it.\nIt's a required field. Default value is 1 and 0 is not allowed.";
          type = types.int;
        };
        "minDomains" = mkOption {
          description = "MinDomains indicates a minimum number of eligible domains.\nWhen the number of eligible domains with matching topology keys is less than minDomains,\nPod Topology Spread treats \"global minimum\" as 0, and then the calculation of Skew is performed.\nAnd when the number of eligible domains with matching topology keys equals or greater than minDomains,\nthis value has no effect on scheduling.\nAs a result, when the number of eligible domains is less than minDomains,\nscheduler won't schedule more than maxSkew Pods to those domains.\nIf value is nil, the constraint behaves as if MinDomains is equal to 1.\nValid values are integers greater than 0.\nWhen value is not nil, WhenUnsatisfiable must be DoNotSchedule.\n\nFor example, in a 3-zone cluster, MaxSkew is set to 2, MinDomains is set to 5 and pods with the same\nlabelSelector spread as 2/2/2:\n| zone1 | zone2 | zone3 |\n|  P P  |  P P  |  P P  |\nThe number of domains is less than 5(MinDomains), so \"global minimum\" is treated as 0.\nIn this situation, new pod with the same labelSelector cannot be scheduled,\nbecause computed skew will be 3(3 - 0) if new Pod is scheduled to any of the three zones,\nit will violate MaxSkew.";
          type = (types.nullOr types.int);
        };
        "nodeAffinityPolicy" = mkOption {
          description = "NodeAffinityPolicy indicates how we will treat Pod's nodeAffinity/nodeSelector\nwhen calculating pod topology spread skew. Options are:\n- Honor: only nodes matching nodeAffinity/nodeSelector are included in the calculations.\n- Ignore: nodeAffinity/nodeSelector are ignored. All nodes are included in the calculations.\n\nIf this value is nil, the behavior is equivalent to the Honor policy.\nThis is a beta-level feature default enabled by the NodeInclusionPolicyInPodTopologySpread feature flag.";
          type = (types.nullOr types.str);
        };
        "nodeTaintsPolicy" = mkOption {
          description = "NodeTaintsPolicy indicates how we will treat node taints when calculating\npod topology spread skew. Options are:\n- Honor: nodes without taints, along with tainted nodes for which the incoming pod\nhas a toleration, are included.\n- Ignore: node taints are ignored. All nodes are included.\n\nIf this value is nil, the behavior is equivalent to the Ignore policy.\nThis is a beta-level feature default enabled by the NodeInclusionPolicyInPodTopologySpread feature flag.";
          type = (types.nullOr types.str);
        };
        "topologyKey" = mkOption {
          description = "TopologyKey is the key of node labels. Nodes that have a label with this key\nand identical values are considered to be in the same topology.\nWe consider each <key, value> as a \"bucket\", and try to put balanced number\nof pods into each bucket.\nWe define a domain as a particular instance of a topology.\nAlso, we define an eligible domain as a domain whose nodes meet the requirements of\nnodeAffinityPolicy and nodeTaintsPolicy.\ne.g. If TopologyKey is \"kubernetes.io/hostname\", each Node is a domain of that topology.\nAnd, if TopologyKey is \"topology.kubernetes.io/zone\", each zone is a domain of that topology.\nIt's a required field.";
          type = types.str;
        };
        "whenUnsatisfiable" = mkOption {
          description = "WhenUnsatisfiable indicates how to deal with a pod if it doesn't satisfy\nthe spread constraint.\n- DoNotSchedule (default) tells the scheduler not to schedule it.\n- ScheduleAnyway tells the scheduler to schedule the pod in any location,\n  but giving higher precedence to topologies that would help reduce the\n  skew.\nA constraint is considered \"Unsatisfiable\" for an incoming pod\nif and only if every possible node assignment for that pod would violate\n\"MaxSkew\" on some topology.\nFor example, in a 3-zone cluster, MaxSkew is set to 1, and pods with the same\nlabelSelector spread as 3/1/1:\n| zone1 | zone2 | zone3 |\n| P P P |   P   |   P   |\nIf WhenUnsatisfiable is set to DoNotSchedule, incoming pod can only be scheduled\nto zone2(zone3) to become 3/2/1(3/1/2) as ActualSkew(2-1) on zone2(zone3) satisfies\nMaxSkew(1). In other words, the cluster can still be imbalanced, but scheduler\nwon't make it *more* imbalanced.\nIt's a required field.";
          type = types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "matchLabelKeys" = mkOverride 1002 null;
        "minDomains" = mkOverride 1002 null;
        "nodeAffinityPolicy" = mkOverride 1002 null;
        "nodeTaintsPolicy" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTopologySpreadConstraintsLabelSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = (
            types.nullOr (
              types.listOf (
                submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTopologySpreadConstraintsLabelSelectorMatchExpressions"
              )
            )
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStatefulSetPodTopologySpreadConstraintsLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "key is the label key that the selector applies to.";
            type = types.str;
          };
          "operator" = mkOption {
            description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
            type = types.str;
          };
          "values" = mkOption {
            description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
            type = (types.nullOr (types.listOf types.str));
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "tailscale.com.v1alpha1.ProxyClassSpecStaticEndpoints" = {

      options = {
        "nodePort" = mkOption {
          description = "The configuration for static endpoints using NodePort Services.";
          type = (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStaticEndpointsNodePort");
        };
      };

      config = { };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStaticEndpointsNodePort" = {

      options = {
        "ports" = mkOption {
          description = "The port ranges from which the operator will select NodePorts for the Services.\nYou must ensure that firewall rules allow UDP ingress traffic for these ports\nto the node's external IPs.\nThe ports must be in the range of service node ports for the cluster (default `30000-32767`).\nSee https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport.";
          type = (
            types.listOf (submoduleOf "tailscale.com.v1alpha1.ProxyClassSpecStaticEndpointsNodePortPorts")
          );
        };
        "selector" = mkOption {
          description = "A selector which will be used to select the node's that will have their `ExternalIP`'s advertised\nby the ProxyGroup as Static Endpoints.";
          type = (types.nullOr (types.attrsOf types.str));
        };
      };

      config = {
        "selector" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecStaticEndpointsNodePortPorts" = {

      options = {
        "endPort" = mkOption {
          description = "endPort indicates that the range of ports from port to endPort if set, inclusive,\nshould be used. This field cannot be defined if the port field is not defined.\nThe endPort must be either unset, or equal or greater than port.";
          type = (types.nullOr types.int);
        };
        "port" = mkOption {
          description = "port represents a port selected to be used. This is a required field.";
          type = types.int;
        };
      };

      config = {
        "endPort" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassSpecTailscale" = {

      options = {
        "acceptRoutes" = mkOption {
          description = "AcceptRoutes can be set to true to make the proxy instance accept\nroutes advertized by other nodes on the tailnet, such as subnet\nroutes.\nThis is equivalent of passing --accept-routes flag to a tailscale Linux client.\nhttps://tailscale.com/kb/1019/subnets#use-your-subnet-routes-from-other-devices\nDefaults to false.";
          type = (types.nullOr types.bool);
        };
      };

      config = {
        "acceptRoutes" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassStatus" = {

      options = {
        "conditions" = mkOption {
          description = "List of status conditions to indicate the status of the ProxyClass.\nKnown condition types are `ProxyClassReady`.";
          type = (
            types.nullOr (types.listOf (submoduleOf "tailscale.com.v1alpha1.ProxyClassStatusConditions"))
          );
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
      };

    };
    "tailscale.com.v1alpha1.ProxyClassStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "lastTransitionTime is the last time the condition transitioned from one status to another.\nThis should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.";
          type = types.str;
        };
        "message" = mkOption {
          description = "message is a human readable message indicating details about the transition.\nThis may be an empty string.";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "observedGeneration represents the .metadata.generation that the condition was set based upon.\nFor instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date\nwith respect to the current state of the instance.";
          type = (types.nullOr types.int);
        };
        "reason" = mkOption {
          description = "reason contains a programmatic identifier indicating the reason for the condition's last transition.\nProducers of specific condition types may define expected values and meanings for this field,\nand whether the values are considered a guaranteed API.\nThe value should be a CamelCase string.\nThis field may not be empty.";
          type = types.str;
        };
        "status" = mkOption {
          description = "status of the condition, one of True, False, Unknown.";
          type = types.str;
        };
        "type" = mkOption {
          description = "type of condition in CamelCase or in foo.example.com/CamelCase.";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };

  };
in
{
  # all resource versions
  options = {
    resources = {
      "tailscale.com"."v1alpha1"."ProxyClass" = mkOption {
        description = "ProxyClass describes a set of configuration parameters that can be applied to\nproxy resources created by the Tailscale Kubernetes operator.\nTo apply a given ProxyClass to resources created for a tailscale Ingress or\nService, use tailscale.com/proxy-class=<proxyclass-name> label. To apply a\ngiven ProxyClass to resources created for a Connector, use\nconnector.spec.proxyClass field.\nProxyClass is a cluster scoped resource.\nMore info:\nhttps://tailscale.com/kb/1445/kubernetes-operator-customization#cluster-resource-customization-using-proxyclass-custom-resource";
        type = (
          types.attrsOf (
            submoduleForDefinition "tailscale.com.v1alpha1.ProxyClass" "proxyclasses" "ProxyClass"
              "tailscale.com"
              "v1alpha1"
          )
        );
        default = { };
      };

    }
    // {
      "proxyClasses" = mkOption {
        description = "ProxyClass describes a set of configuration parameters that can be applied to\nproxy resources created by the Tailscale Kubernetes operator.\nTo apply a given ProxyClass to resources created for a tailscale Ingress or\nService, use tailscale.com/proxy-class=<proxyclass-name> label. To apply a\ngiven ProxyClass to resources created for a Connector, use\nconnector.spec.proxyClass field.\nProxyClass is a cluster scoped resource.\nMore info:\nhttps://tailscale.com/kb/1445/kubernetes-operator-customization#cluster-resource-customization-using-proxyclass-custom-resource";
        type = (
          types.attrsOf (
            submoduleForDefinition "tailscale.com.v1alpha1.ProxyClass" "proxyclasses" "ProxyClass"
              "tailscale.com"
              "v1alpha1"
          )
        );
        default = { };
      };

    };
  };

  config = {
    # expose resource definitions
    inherit definitions;

    # register resource types
    types = [
      {
        name = "proxyclasses";
        group = "tailscale.com";
        version = "v1alpha1";
        kind = "ProxyClass";
        attrName = "proxyClasses";
      }
    ];

    resources = {
      "tailscale.com"."v1alpha1"."ProxyClass" = mkAliasDefinitions options.resources."proxyClasses";

    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [ ];
  };
}

{
  lib,
  config,
  ...
}: let
  cfg = config.networking.cilium;

  chart = lib.helm.downloadHelmChart {
    repo = "https://helm.cilium.io/";
    chart = "cilium";
    version = "1.14.4";
    chartHash = "sha256-Rd1KmIB5uYrSQ/aCBqmX/zFv9FwX0svD2+lcqV4yoEM=";
  };

  namespace = "kube-system";

  values =
    lib.attrsets.recursiveUpdate {
      operator.replicas = 1;

      # Default CIDR in k3s.
      ipam.operator.clusterPoolIPv4PodCIDRList = ["10.42.0.0/16"];

      # Policy enforcement.
      policyEnforcementMode = "always";
      policyAuditMode = true;

      # Set Cilium as a kube-proxy replacement.
      kubeProxyReplacement = true;

      # Each node in a k3s cluster runs a local
      # load balancer for the API server on port
      # 6444.
      k8sServiceHost = "localhost";
      k8sServicePort = 6444;

      # Needed for the tailscale proxy setup to work.
      socketLB.hostNamespaceOnly = true;
      bpf.lbExternalClusterIP = true;

      # Enable Hubble UI.
      hubble = {
        relay.enabled = true;
        ui.enabled = true;
        # This should be used so the rendered manifest
        # doesn't contain TLS secrets.
        tls.auto.method = "cronJob";
      };
    }
    cfg.values;
in {
  options.networking.cilium = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    applications.cilium = {
      inherit namespace;

      helm.releases.cilium = {
        inherit chart values;
      };

      # TODO: add network policies
    };

    # Set resource exclusions in argocd
    services.argocd.values.configs.cm."resource.exclusions" = ''
      - apiGroups:
        - cilium.io
        kinds:
        - CiliumIdentity
        clusters:
        - "*"
    '';
  };
}

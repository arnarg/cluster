{
  lib,
  config,
  ...
}: let
  cfg = config.networking.cilium;

  chart = lib.helm.downloadHelmChart {
    repo = "https://helm.cilium.io/";
    chart = "cilium";
    version = "1.15.4";
    chartHash = "sha256-zge93cptvS6Qpd6hN3L76AfI4BqynXSwn+Fv/v0Zpgw=";
  };

  namespace = "kube-system";

  values =
    lib.attrsets.recursiveUpdate {
      operator.replicas = 1;

      # Having this enabled breaks DNS proxying in
      # my cluster because the hosts are IPv6 enabled
      # but Cilium isn't.
      # See: https://github.com/cilium/cilium/issues/31197
      dnsProxy.enableTransparentMode = false;

      # Default CIDR in k3s.
      ipam.operator.clusterPoolIPv4PodCIDRList = ["10.42.0.0/16"];

      # Policy enforcement.
      policyEnforcementMode = "always";
      policyAuditMode = false;

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

      yamls = [
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumClusterwideNetworkPolicy
          metadata:
            name: allow-internal-egress
            namespace: kube-system
          spec:
            description: "Policy to allow all Cilium managed endpoint to talk to all other cilium managed endpoints on egress"
            endpointSelector: {}
            egress:
            - toEndpoints:
              - {}
        ''
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumClusterwideNetworkPolicy
          metadata:
            name: "cilium-health-checks"
            namespace: kube-system
          spec:
            endpointSelector:
              matchLabels:
                'reserved:health': ""
            ingress:
              - fromEntities:
                - remote-node
            egress:
              - toEntities:
                - remote-node
        ''
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-hubble-relay-server-egress
            namespace: kube-system
          spec:
            description: "Policy for egress from hubble relay to hubble server in Cilium agent."
            endpointSelector:
              matchLabels:
                app.kubernetes.io/name: hubble-relay
            egress:
            - toEntities:
              - remote-node
              - host
              toPorts:
              - ports:
                - port: "4244"
                  protocol: TCP
        ''
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-hubble-ui-relay-ingress
            namespace: kube-system
          spec:
            description: "Policy for ingress from hubble UI to hubble relay."
            endpointSelector:
              matchLabels:
                app.kubernetes.io/name: hubble-relay
            ingress:
            - fromEndpoints:
              - matchLabels:
                  app.kubernetes.io/name: hubble-ui
              toPorts:
              - ports:
                - port: "4245"
                  protocol: TCP
        ''
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-hubble-ui-kube-apiserver-egress
            namespace: kube-system
          spec:
            description: "Allow Hubble UI to talk to kube-apiserver"
            endpointSelector:
              matchLabels:
                app.kubernetes.io/name: hubble-ui
            egress:
            - toEntities:
              - kube-apiserver
              toPorts:
              - ports:
                - port: "6443"
                  protocol: TCP
        ''
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumClusterwideNetworkPolicy
          metadata:
            name: allow-kube-dns-cluster-ingress
            namespace: kube-system
          spec:
            description: "Policy for ingress allow to kube-dns from all Cilium managed endpoints in the cluster"
            endpointSelector:
              matchLabels:
                k8s:io.kubernetes.pod.namespace: kube-system
                k8s-app: kube-dns
            ingress:
            - fromEndpoints:
              - {}
              toPorts:
              - ports:
                - port: "53"
                  protocol: UDP
        ''
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-kube-dns-upstream-egress
            namespace: kube-system
          spec:
            description: "Policy for egress to allow kube-dns to talk to upstream DNS."
            endpointSelector:
              matchLabels:
                k8s-app: kube-dns
            egress:
            - toEntities:
              - world
              toPorts:
              - ports:
                - port: "53"
                  protocol: UDP
        ''
        ''
          apiVersion: "cilium.io/v2"
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-kube-dns-apiserver-egress
            namespace: kube-system
          spec:
            description: "Allow coredns to talk to kube-apiserver"
            endpointSelector:
              matchLabels:
                k8s-app: kube-dns
            egress:
            - toEntities:
              - kube-apiserver
              toPorts:
              - ports:
                - port: "6443"
                  protocol: TCP
        ''
      ];
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

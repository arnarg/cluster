{
  lib,
  config,
  charts,
  ...
}: let
  cfg = config.networking.tailscale-operator;

  namespace = "tailscale";

  values =
    lib.attrsets.recursiveUpdate {
      # Default values
    }
    cfg.values;
in {
  options.networking.tailscale-operator = with lib; {
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
    applications.tailscale-operator = {
      inherit namespace;

      helm.releases.tailscale-operator = {
        inherit values;
        chart = charts.tailscale.tailscale-operator;
      };

      yamls = [
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-tailscale-https-egress
            namespace: ${namespace}
          spec:
            description: "Policy to allow egress HTTPS traffic to tailscale coordination servers and derp servers."
            endpointSelector: {}
            egress:
            # Enable DNS proxying
            - toEndpoints:
              - matchLabels:
                 "k8s:io.kubernetes.pod.namespace": kube-system
                 "k8s:k8s-app": kube-dns
              toPorts:
              - ports:
                - port: "53"
                  protocol: ANY
                rules:
                  dns:
                  - matchPattern: "*"
            # Allow HTTPS to coordination and derp servers
            - toFQDNs:
              - matchPattern: "*.tailscale.com"
              toPorts:
              - ports:
                - port: "443"
                  protocol: TCP
                - port: "80"
                  protocol: TCP
        ''
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-kube-apiserver-egress
            namespace: ${namespace}
          spec:
            description: "Policy to allow pods to talk to kube apiserver"
            endpointSelector: {}
            egress:
            - toEntities:
              - kube-apiserver
              toPorts:
              - ports:
                - port: "6443"
                  protocol: TCP
        ''
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-tailscale-traffic-egress
            namespace: ${namespace}
          spec:
            description: "Policy to allow pods to send necessary UDP traffic to work."
            endpointSelector: {}
            egress:
            # All UDP traffic for tailscale to work.
            # I have only observed  ports in this range
            - toEntities:
              - world
              toPorts:
              - ports:
                - port: "0"
                  protocol: UDP
            egressDeny:
            # Deny attempt to use SSDP
            - toEntities:
              - world
              toPorts:
              - ports:
                - port: "1900"
                  protocol: UDP
        ''
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-egress
            namespace: ${namespace}
          spec:
            description: "Policy for egress to allow tailscale components to talk to traefik, k8s-gateway and tailscale required traffic"
            endpointSelector:
              # The proxies do not have predictable labels
              # so I have to allow the whole namespace.
              matchLabels:
                k8s:io.kubernetes.pod.namespace: tailscale
            egress:
            # Talk to k8s-gateway
            - toEndpoints:
              - matchLabels:
                  app.kubernetes.io/name: k8s-gateway
                  k8s:io.kubernetes.pod.namespace: k8s-gateway
              toPorts:
              - ports:
                - port: "1053"
                  protocol: UDP
            # Talk to required Tailscale ports
            - toEntities:
              - world
              toPorts:
              - ports:
                - port: "443"
                  protocol: TCP
                - port: "3478"
                  protocol: UDP
        ''

        # Load SOPS encrypted secret
        (builtins.readFile ./tailscale-secret.sops.yaml)
      ];

      # Patch some extra resources
      resources = {
        # The tailscale namespace needs a privileged pod security
        # policy.
        namespaces."${namespace}" = {
          metadata.labels."pod-security.kubernetes.io/enforce" = lib.mkForce "privileged";
        };
        # Make sure the SOPS secret has correct namespace
        sopsSecrets.tailscale-secrets.metadata.namespace = namespace;
      };
    };

    # Set traefik's service to use tailscale-operator
    networking.traefik.values.service = {
      loadBalancerClass = "tailscale";
      annotations = {
        "tailscale.com/hostname" = "k8s-ingress";
        "tailscale.com/tags" = "tag:web";
      };
    };

    # Set k8s-gateway's service to use tailscale-operator
    applications.k8s-gateway.resources.services.k8s-gateway = {
      metadata.annotations = {
        "tailscale.com/hostname" = "k8s-dns";
        "tailscale.com/tags" = "tag:dns";
      };
      spec.loadBalancerClass = "tailscale";
    };
  };
}

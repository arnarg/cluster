{
  lib,
  config,
  charts,
  ...
}: let
  cfg = config.networking.cilium;

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
    nixidy.resourceImports = [./resource.nix];

    applications.cilium = {
      inherit namespace;

      helm.releases.cilium = {
        inherit values;
        chart = charts.cilium.cilium;
      };

      resources = {
        # Allow all cilium endpoints to talk egress to each other
        ciliumclusterwidenetworkpolicies.allow-internal-egress.spec = {
          description = "Policy to allow all Cilium managed endpoint to talk to all other cilium managed endpoints on egress";
          endpointSelector = {};
          egress = [
            {
              toEndpoints = [{}];
            }
          ];
        };

        # Allow all health checks
        ciliumclusterwidenetworkpolicies.cilium-health-checks.spec = {
          endpointSelector.matchLabels."reserved:health" = "";
          ingress = [
            {
              fromEntities = ["remote-node"];
            }
          ];
          egress = [
            {
              toEntities = ["remote-node"];
            }
          ];
        };

        # Allow hubble relay server egress to nodes
        ciliumnetworkpolicies.allow-hubble-relay-server-egress.spec = {
          description = "Policy for egress from hubble relay to hubble server in Cilium agent.";
          endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-relay";
          egress = [
            {
              toEntities = ["remote-node" "host"];
              toPorts = [
                {
                  ports = [
                    {
                      port = "4244";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };

        # Allow hubble UI to talk to hubble relay
        ciliumnetworkpolicies.allow-hubble-ui-relay-ingress.spec = {
          description = "Policy for ingress from hubble UI to hubble relay.";
          endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-relay";
          ingress = [
            {
              fromEndpoints = [
                {
                  matchLabels."app.kubernetes.io/name" = "hubble-ui";
                }
              ];
              toPorts = [
                {
                  ports = [
                    {
                      port = "4245";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };

        # Allow hubble UI to talk to kube-apiserver
        ciliumnetworkpolicies.allow-hubble-ui-kube-apiserver-egress.spec = {
          description = "Allow Hubble UI to talk to kube-apiserver";
          endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-ui";
          egress = [
            {
              toEntities = ["kube-apiserver"];
              toPorts = [
                {
                  ports = [
                    {
                      port = "6443";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };

        # Allow all cilium managed endpoints to talk to cluster dns
        ciliumclusterwidenetworkpolicies.allow-kube-dns-cluster-ingress.spec = {
          description = "Policy for ingress allow to kube-dns from all Cilium managed endpoints in the cluster.";
          endpointSelector.matchLabels = {
            "k8s:io.kubernetes.pod.namespace" = "kube-system";
            "k8s-app" = "kube-dns";
          };
          ingress = [
            {
              fromEndpoints = [{}];
              toPorts = [
                {
                  ports = [
                    {
                      port = "53";
                      protocol = "UDP";
                    }
                  ];
                }
              ];
            }
          ];
        };

        # Allow kube-dns to talk to upstream DNS
        ciliumnetworkpolicies.allow-kube-dns-upstream-egress.spec = {
          description = "Policy for egress to allow kube-dns to talk to upstream DNS.";
          endpointSelector.matchLabels.k8s-app = "kube-dns";
          egress = [
            {
              toEntities = ["world"];
              toPorts = [
                {
                  ports = [
                    {
                      port = "53";
                      protocol = "UDP";
                    }
                  ];
                }
              ];
            }
          ];
        };

        # Allow CoreDNS to talk to kube-apiserver
        ciliumnetworkpolicies.allow-kube-dns-apiserver-egress.spec = {
          description = "Allow coredns to talk to kube-apiserver.";
          endpointSelector.matchLabels.k8s-app = "kube-dns";
          egress = [
            {
              toEntities = ["kube-apiserver"];
              toPorts = [
                {
                  ports = [
                    {
                      port = "6443";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };
      };
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

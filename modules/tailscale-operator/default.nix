{
  lib,
  config,
  charts,
  ...
}:
let
  cfg = config.networking.tailscale-operator;

  namespace = "tailscale";

  values = lib.attrsets.recursiveUpdate {
    # Default values
  } cfg.values;
in
{
  options.networking.tailscale-operator = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    nixidy.applicationImports = [ ./generated.nix ];

    applications.tailscale-operator = {
      inherit namespace;

      helm.releases.tailscale-operator = {
        inherit values;
        chart = charts.tailscale.tailscale-operator;
      };

      # Load tailscale credentials from 1password
      templates.opSecret.operator-oauth.itemName = "tailscale_oauth";

      resources = {
        # The tailscale namespace needs a privileged pod security
        # policy.
        namespaces."${namespace}" = {
          metadata.labels."pod-security.kubernetes.io/enforce" = lib.mkForce "privileged";
        };

        # Add labels to tailscale-operator pod
        deployments.operator.spec.template.metadata.labels."argocd.argoproj.io/part-of" =
          "tailscale-operator";

        # Create a tailscale proxy class to set labels on proxies
        proxyClasses.prod.spec.statefulSet.pod.labels."argocd.argoproj.io/part-of" = "tailscale-operator";

        ciliumNetworkPolicies = {
          # Allow tailscale-operator access to kube-apiserver
          allow-kube-apiserver-egress.spec = {
            description = "Policy to allow pods to talk to kube apiserver";
            endpointSelector.matchLabels."argocd.argoproj.io/part-of" = "tailscale-operator";
            egress = [
              {
                toEntities = [ "kube-apiserver" ];
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

          # Allow tailscale-operator pods HTTPS egress access
          allow-tailscale-https-egress.spec = {
            description = "Policy to allow egress HTTPS traffic to tailscale coordination servers and derp servers.";
            endpointSelector.matchLabels."argocd.argoproj.io/part-of" = "tailscale-operator";
            egress = [
              # Enable DNS proxying
              {
                toEndpoints = [
                  {
                    matchLabels = {
                      "k8s:io.kubernetes.pod.namespace" = "kube-system";
                      "k8s:k8s-app" = "kube-dns";
                    };
                  }
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "53";
                        protocol = "ANY";
                      }
                    ];
                    rules.dns = [
                      { matchPattern = "*"; }
                    ];
                  }
                ];
              }
              # Allow HTTPS to coordination and derp servers
              {
                toFQDNs = [
                  { matchPattern = "*.tailscale.com"; }
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "443";
                        protocol = "TCP";
                      }
                      {
                        port = "80";
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          # Allow tailscale-operator pods necessary UDP traffic
          allow-tailscale-traffic-egress.spec = {
            description = "Policy to allow pods to send necessary UDP traffic to work.";
            endpointSelector.matchLabels."argocd.argoproj.io/part-of" = "tailscale-operator";
            # Allow all UDP ports
            egress = [
              {
                toEntities = [ "world" ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "0";
                        protocol = "UDP";
                      }
                    ];
                  }
                ];
              }
            ];
            # Deny SSDP
            egressDeny = [
              {
                toEntities = [ "world" ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "1900";
                        protocol = "UDP";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          # Allow egress to traefik, k8s-gateway and tailscale required traffic
          allow-egress.spec = {
            description = "Policy for egress to allow tailscale components to talk to traefik, k8s-gateway and tailscale required traffic.";
            endpointSelector.matchLabels."argocd.argoproj.io/part-of" = "tailscale-operator";
            egress = [
              # Talk to k8s-gateway
              {
                toEndpoints = [
                  {
                    matchLabels = {
                      "app.kubernetes.io/name" = "k8s-gateway";
                      "k8s:io.kubernetes.pod.namespace" = "k8s-gateway";
                    };
                  }
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "1053";
                        protocol = "UDP";
                      }
                    ];
                  }
                ];
              }
              # Talk to required Tailscale ports
              {
                toEntities = [ "world" ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "443";
                        protocol = "TCP";
                      }
                      {
                        port = "3478";
                        protocol = "UDP";
                      }
                    ];
                  }
                ];
              }
            ];
          };
        };
      };
    };

    # Set traefik's service to use tailscale-operator
    networking.traefik.values.service = {
      loadBalancerClass = "tailscale";
      annotations = {
        "tailscale.com/hostname" = "k8s-ingress";
        "tailscale.com/tags" = "tag:web";
      };
      labels = {
        "tailscale.com/proxy-class" = "prod";
      };
    };

    # Set k8s-gateway's service to use tailscale-operator
    applications.k8s-gateway.resources.services.k8s-gateway = {
      metadata.annotations = {
        "tailscale.com/hostname" = "k8s-dns";
        "tailscale.com/tags" = "tag:dns";
      };
      metadata.labels = {
        "tailscale.com/proxy-class" = "prod";
      };
      spec.loadBalancerClass = "tailscale";
    };
  };
}

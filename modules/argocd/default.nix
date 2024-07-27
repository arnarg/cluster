{
  lib,
  config,
  charts,
  ...
}: let
  cfg = config.services.argocd;

  namespace = "argocd";

  values =
    lib.attrsets.recursiveUpdate {
      server.ingress = {
        inherit (config.networking.traefik) ingressClassName;

        enabled = true;
        hostname = "argocd.${config.networking.domain}";
      };

      repoServer.dnsConfig.options = [
        {
          name = "ndots";
          value = "1";
        }
      ];

      configs = {
        # Leave here until migration to nixidy is done.
        cm."kustomize.buildOptions" = "--enable-helm";

        # Traefik will terminate TLS so argocd-server
        # can run with plain HTTP.
        params."server.insecure" = "true";
      };

      global.networkPolicy.create = true;
    }
    cfg.values;
in {
  options.services.argocd = with lib; {
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
    applications.argocd = {
      inherit namespace;

      helm.releases.argocd = {
        inherit values;
        chart = charts.argoproj.argo-cd;
      };

      resources = {
        # Allow ingress traffic from traefik to
        # argocd-server.
        networkPolicies.allow-traefik-ingress.spec = {
          podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
          policyTypes = ["Ingress"];
          ingress = [
            {
              from = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "traefik";
                  podSelector.matchLabels."app.kubernetes.io/name" = "traefik";
                }
              ];
              ports = [
                {
                  protocol = "TCP";
                  port = 8080;
                }
              ];
            }
          ];
        };

        ciliumNetworkPolicies = {
          # Allow argocd-repo-server egress access to github.com
          allow-world-egress.spec = {
            endpointSelector.matchLabels."app.kubernetes.io/name" = "argocd-repo-server";
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
                      {matchPattern = "*";}
                    ];
                  }
                ];
              }
              # Allow HTTPS to github.com
              {
                toFQDNs = [
                  {matchName = "github.com";}
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "443";
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }
            ];
          };

          # Allow all ArgoCD pods to access kube-apiserver
          allow-kube-apiserver-egress.spec = {
            endpointSelector.matchLabels."app.kubernetes.io/part-of" = "argocd";
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
    };
  };
}

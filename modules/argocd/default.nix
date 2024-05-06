{
  lib,
  config,
  ...
}: let
  cfg = config.services.argocd;

  chart = lib.helm.downloadHelmChart {
    repo = "https://argoproj.github.io/argo-helm/";
    chart = "argo-cd";
    version = "6.7.18";
    chartHash = "sha256-FWk0b9QyxC2dXuB9uK6A5OO999JghFucS4iOu2QNNNY=";
  };

  namespace = "argocd";

  values =
    lib.attrsets.recursiveUpdate {
      server.ingress = {
        enabled = true;
        hosts = ["argocd.${config.networking.domain}"];
        ingressClass = config.networking.traefik.ingressClassName;
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
        inherit chart values;
      };

      # Network policies
      yamls = [
        ''
          apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: allow-traefik-ingress
            namespace: ${namespace}
          spec:
            podSelector:
              matchLabels:
                app.kubernetes.io/name: argocd-server
            policyTypes:
            - Ingress
            ingress:
            - from:
              - namespaceSelector:
                  matchLabels:
                    kubernetes.io/metadata.name: traefik
                podSelector:
                  matchLabels:
                    app.kubernetes.io/name: traefik
              ports:
                - protocol: TCP
                  port: 8080
        ''
        # ''
        #   apiVersion: cilium.io/v2
        #   kind: CiliumNetworkPolicy
        #   metadata:
        #     name: allow-world-egress
        #     namespace: ${namespace}
        #   spec:
        #     endpointSelector:
        #       matchLabels:
        #         app.kubernetes.io/name: argocd-repo-server
        #     egress:
        #     # Enable DNS proxying
        #     - toEndpoints:
        #       - matchLabels:
        #          "k8s:io.kubernetes.pod.namespace": kube-system
        #          "k8s:k8s-app": kube-dns
        #       toPorts:
        #       - ports:
        #         - port: "53"
        #           protocol: ANY
        #         rules:
        #           dns:
        #           - matchPattern: "*"
        #     # Allow HTTPS to github
        #     - toFQDNs:
        #       - matchName: github.com.
        #       toPorts:
        #       - ports:
        #         - port: "443"
        #           protocol: TCP
        # ''
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-kube-apiserver-egress
            namespace: ${namespace}
          spec:
            endpointSelector: {}
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
  };
}
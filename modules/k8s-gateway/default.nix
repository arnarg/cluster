{
  lib,
  config,
  ...
}: let
  chart = lib.helm.downloadHelmChart {
    repo = "https://ori-edge.github.io/k8s_gateway/";
    chart = "k8s-gateway";
    version = "2.4.0";
    chartHash = "sha256-Csj8/HKh8umXd2hyfF5svKxY5d1SnKAvpuEPCSijloo=";
  };

  namespace = "k8s-gateway";
in {
  applications.k8s-gateway = {
    inherit namespace;
    createNamespace = true;

    helm.releases.k8s-gateway = {
      inherit chart;

      values = {
        domain = config.networking.domain;

        # Only watch ingresses.
        watchedResources = ["Ingress"];

        # Fallthrough on miss.
        fallthrough.enabled = true;

        # Add forward to cloudflare DNS.
        extraZonePlugins = [
          # Copied from standard values.yaml.
          {name = "log";}
          {name = "errors";}
          {
            name = "health";
            configBlock = ''
              lameduck 5s
            '';
          }
          {name = "ready";}
          {
            name = "prometheus";
            parameters = "0.0.0.0:9153";
          }
          # My custom forward to cloudflare DNS over TLS.
          {
            name = "forward";
            parameters = "cdbrdr.com tls://1.1.1.1 tls://1.0.0.1";
            configBlock = ''
              tls_servername cloudflare-dns.com
            '';
          }
          {name = "loop";}
          {name = "reload";}
          {name = "loadbalance";}
        ];
      };
    };

    # Network policies
    yamls = [
      ''
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: allow-tailscale-ingress
          namespace: ${namespace}
        spec:
          podSelector:
            matchLabels:
              app.kubernetes.io/name: k8s-gateway
          policyTypes:
          - Ingress
          ingress:
          - from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: tailscale
            ports:
            - protocol: UDP
              port: 1053
      ''
      ''
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: allow-upstream-tls-dns-egress
          namespace: ${namespace}
        spec:
          podSelector:
            matchLabels:
              app.kubernetes.io/name: k8s-gateway
          policyTypes:
          - Egress
          egress:
          - to:
            - ipBlock:
                cidr: 1.1.1.1/32
            - ipBlock:
                cidr: 1.0.0.1/32
            ports:
            - protocol: TCP
              port: 853
      ''
      ''
        apiVersion: cilium.io/v2
        kind: CiliumNetworkPolicy
        metadata:
          name: allow-kube-apiserver-egress
          namespace: ${namespace}
        spec:
          endpointSelector:
            matchLabels:
              app.kubernetes.io/name: k8s-gateway
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
}

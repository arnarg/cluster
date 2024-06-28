{
  config,
  charts,
  ...
}: let
  namespace = "k8s-gateway";
in {
  applications.k8s-gateway = {
    inherit namespace;
    createNamespace = true;

    helm.releases.k8s-gateway = {
      chart = charts.ori-edge.k8s-gateway;

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

    resources = {
      # Network policy allowing k8s-gateway to make
      # DNS over TLS requests to 1.1.1.1 and 1.0.0.1.
      networkPolicies.allow-upstream-tls-dns-egress.spec = {
        podSelector.matchLabels."app.kubernetes.io/name" = "k8s-gateway";
        policyTypes = ["Egress"];
        egress = [
          {
            to = [
              {ipBlock.cidr = "1.1.1.1/32";}
              {ipBlock.cidr = "1.0.0.1/32";}
            ];
            ports = [
              {
                protocol = "TCP";
                port = 853;
              }
            ];
          }
        ];
      };

      # Network policy allowing tailscale proxy to
      # make DNS requests to k8s-gateway.
      networkPolicies.allow-tailscale-ingress.spec = {
        podSelector.matchLabels."app.kubernetes.io/name" = "k8s-gateway";
        policyTypes = ["Ingress"];
        ingress = [
          {
            from = [
              {
                namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "tailscale";
                podSelector.matchLabels."tailscale.com/parent-resource" = "k8s-gateway";
              }
            ];
            ports = [
              {
                protocol = "UDP";
                port = 1053;
              }
            ];
          }
        ];
      };

      # Allow k8s-gateway to access kube-apiserver
      ciliumNetworkPolicies.allow-kube-apiserver-egress.spec = {
        endpointSelector.matchLabels."app.kubernetes.io/name" = "k8s-gateway";
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
}

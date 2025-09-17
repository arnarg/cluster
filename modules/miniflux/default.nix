{ config, ... }:
let
  namespace = "miniflux";

  labels = {
    "app.kubernetes.io/name" = "miniflux";
  };

  port = 8080;
in
{
  applications.miniflux = {
    inherit namespace;
    createNamespace = true;

    templates = {
      # Load credentials from 1password
      opSecret.miniflux-creds.itemName = "miniflux_creds";

      # Render the webApplication template
      webApplication.miniflux = {
        inherit port;
        image = "ghcr.io/miniflux/miniflux:2.2.12-distroless";
        env = {
          DATABASE_URL.valueFrom.secretKeyRef = {
            name = "miniflux-creds";
            key = "databaseConn";
          };
          ADMIN_USERNAME.valueFrom.secretKeyRef = {
            name = "miniflux-creds";
            key = "adminUser";
          };
          ADMIN_PASSWORD.valueFrom.secretKeyRef = {
            name = "miniflux-creds";
            key = "adminPassword";
          };
          LISTEN_ADDR.value = "0.0.0.0:${toString port}";
          RUN_MIGRATIONS.value = "1";
          CREATE_ADMIN.value = "1";
        };
        ingress = {
          inherit (config.networking.traefik) ingressClassName;
          host = "reader.${config.networking.domain}";
        };
      };
    };

    resources = {
      # Set custom dnsConfig in miniflux deployment
      deployments.miniflux.spec.template.spec.dnsConfig = {
        options.ndots.value = "1";
      };

      networkPolicies.allow-traefik-ingress.spec = {
        podSelector.matchLabels = labels;
        policyTypes = [ "Ingress" ];
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
                inherit port;
                protocol = "TCP";
              }
            ];
          }
        ];
      };

      # Allow miniflux to talk to postgres
      ciliumNetworkPolicies.allow-postgres-egress.spec = {
        endpointSelector.matchLabels = labels;
        egress = [
          {
            toEntities = [
              # The PostgreSQL server is hosted on the same
              # node as the kubernetes API server.
              # Cilium will always match this as the entity
              # `kube-apiserver` instead of the CIDR.
              # See: https://github.com/cilium/cilium/issues/16308
              "kube-apiserver"
            ];
            toPorts = [
              {
                ports = [
                  {
                    port = "5432";
                    protocol = "TCP";
                  }
                ];
              }
            ];
          }
        ];
      };

      # Allow egress HTTPS to the internet
      ciliumNetworkPolicies.allow-rss-feeds-egress.spec = {
        endpointSelector.matchLabels = labels;
        egress = [
          {
            toEntities = [ "world" ];
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
    };
  };
}

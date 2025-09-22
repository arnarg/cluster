{ config, ... }:
let
  namespace = "shiori";

  labels = {
    "app.kubernetes.io/name" = "shiori";
  };

  port = 8080;
in
{
  applications.shiori = {
    inherit namespace;
    createNamespace = true;

    templates = {
      # Load credentials from 1password
      opSecret.shiori-creds.itemName = "shiori_creds";

      # Render the webApplication template
      webApplication.shiori = {
        inherit port;
        image = "ghcr.io/go-shiori/shiori:v1.7.4";
        env = {
          SHIORI_DIR.value = "/data";
          SHIORI_HTTP_SECRET_KEY.valueFrom.secretKeyRef = {
            name = "shiori-creds";
            key = "secretKey";
          };
          SHIORI_DATABASE_URL.valueFrom.secretKeyRef = {
            name = "shiori-creds";
            key = "databaseConn";
          };
        };
        ingress = {
          inherit (config.networking.traefik) ingressClassName;
          host = "shiori.${config.networking.domain}";
        };
      };
    };

    resources = {
      # Patch deployment to set options not present
      # in the simple webApplication template.
      deployments.shiori.spec.template.spec = {
        containers.shiori = {
          args = [
            "serve"
            "--address"
            "0.0.0.0"
            "--port"
            (toString port)
          ];
          volumeMounts."/data".name = "data";
        };
        securityContext.fsGroup = 2000;
        volumes.data.persistentVolumeClaim.claimName = "shiori";
      };

      persistentVolumeClaims.shiori = {
        metadata.namespace = namespace;
        spec = {
          inherit (config.storage.csi.nfs) storageClassName;

          volumeMode = "Filesystem";
          accessModes = [ "ReadWriteOnce" ];
          resources.requests.storage = "10Gi";
        };
      };

      services.shiori.spec = {
        type = "ClusterIP";
        selector = labels;
        ports.http = {
          port = 80;
          protocol = "TCP";
          targetPort = port;
        };
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

      ciliumNetworkPolicies = {
        # Allow shiori to talk to postgres
        allow-postgres-egress.spec = {
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
        allow-https-world-egress.spec = {
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
  };
}

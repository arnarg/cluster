{config, ...}: let
  namespace = "shiori";

  labels = {"app.kubernetes.io/name" = "shiori";};
in {
  applications.shiori = {
    inherit namespace;
    createNamespace = true;

    resources = let
      port = 8080;
    in {
      deployments.shiori = {
        metadata.labels = labels;
        spec = {
          replicas = 1;
          selector.matchLabels = labels;
          template = {
            metadata.labels = labels;
            spec = {
              containers.shiori = {
                image = "ghcr.io/go-shiori/shiori:v1.7.0";
                args = [
                  "serve"
                  "--address"
                  "0.0.0.0"
                  "--port"
                  (toString port)
                ];
                ports.http.containerPort = port;
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
                volumeMounts."/data".name = "data";
              };
              securityContext.fsGroup = 2000;
              volumes.data.persistentVolumeClaim.claimName = "shiori";
            };
          };
        };
      };

      persistentVolumeClaims.shiori = {
        metadata.namespace = namespace;
        spec = {
          inherit (config.storage.csi.nfs) storageClassName;

          volumeMode = "Filesystem";
          accessModes = ["ReadWriteOnce"];
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

      ingresses.shiori.spec = {
        inherit (config.networking.traefik) ingressClassName;

        rules = [
          {
            host = "shiori.${config.networking.domain}";
            http.paths = [
              {
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "shiori";
                  port.name = "http";
                };
              }
            ];
          }
        ];
      };

      networkPolicies.allow-traefik-ingress.spec = {
        podSelector.matchLabels = labels;
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
              toEntities = ["world"];
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

    yamls = [
      # Read SOPS encrypted secret
      (builtins.readFile ./shiori-secret.sops.yaml)
    ];
  };
}

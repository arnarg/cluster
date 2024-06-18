{
  lib,
  config,
  ...
}: let
  inherit (builtins) toJSON;

  namespace = "miniflux";

  labels = {
    "app.kubernetes.io/name" = "miniflux";
  };
in {
  applications.miniflux = {
    inherit namespace;
    createNamespace = true;

    resources = let
      port = 8080;
    in {
      deployments.miniflux = {
        metadata.labels = labels;
        spec = {
          replicas = 1;
          selector.matchLabels = labels;
          template = {
            metadata.labels = labels;
            spec.containers.miniflux = {
              image = "ghcr.io/miniflux/miniflux:2.1.3-distroless";
              ports.http.containerPort = port;
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
            };
          };
        };
      };

      services.miniflux.spec = {
        type = "ClusterIP";
        selector = labels;
        ports.http = {
          port = 80;
          protocol = "TCP";
          targetPort = port;
        };
      };

      ingresses.miniflux.spec = {
        ingressClassName = config.networking.traefik.ingressClassName;
        rules = [
          {
            host = "reader.${config.networking.domain}";
            http.paths = [
              {
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "miniflux";
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
                protocol = "TCP";
                port = port;
              }
            ];
          }
        ];
      };

      # Make sure the SOPS secret has correct namespace
      sopsSecrets.miniflux-secrets.metadata.namespace = lib.mkForce namespace;
    };

    yamls = [
      ''
        apiVersion: cilium.io/v2
        kind: CiliumNetworkPolicy
        metadata:
          name: allow-postgres-egress
          namespace: ${namespace}
        spec:
          endpointSelector:
            matchLabels: ${toJSON labels}
          # Allow egress traffic to postgresql
          egress:
          - toEntities:
            # The PostgreSQL server is hosted on the same
            # node as the kubernetes API server.
            # Cilium will always match this as the entity
            # `kube-apiserver` instead of the CIDR.
            # See: https://github.com/cilium/cilium/issues/16308
            - kube-apiserver
            toPorts:
            - ports:
              - port: "5432"
                protocol: TCP
      ''

      ''
        apiVersion: cilium.io/v2
        kind: CiliumNetworkPolicy
        metadata:
          name: allow-rss-feeds-egress
          namespace: ${namespace}
        spec:
          endpointSelector:
            matchLabels: ${toJSON labels}
          # Allow egress traffic to https on the internet
          egress:
          - toEntities:
            - world
            toPorts:
            - ports:
              - port: "443"
                protocol: TCP
      ''

      # Read SOPS encrypted secret
      (builtins.readFile ./miniflux-secret.sops.yaml)
    ];
  };
}

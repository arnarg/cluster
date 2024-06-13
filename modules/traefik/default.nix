{
  lib,
  config,
  charts,
  ...
}: let
  cfg = config.networking.traefik;

  namespace = "traefik";

  values =
    lib.attrsets.recursiveUpdate {
      # Create an ingress class.
      ingressClass = {
        enabled = true;
        isDefaultClass = true;
        name = cfg.ingressClassName;
      };

      # Don't send update checks and anonymous data collection.
      globalArguments = [];

      # Automatically set host to published services.
      providers.kubernetesIngress.publishedService.enabled = true;

      # Automatically redirect HTTP to HTTPS
      ports.web.redirectTo.port = "websecure";

      # Use lets encrypt as a cert resolver.
      ports.websecure.tls = {
        enabled = true;
        certResolver = "letsencrypt";
      };

      # Setup cert resolver for lets encrypt.
      certResolvers.letsencrypt = {
        email = "acme@codedbearder.com";
        dnsChallenge.provider = "cloudflare";
        storage = "/data/acme.json";
      };

      # Setup storage for acme data.
      persistence = {
        enabled = true;
        storageClass = config.storage.csi.nfs.storageClassName;
        subPath = "traefik";
      };

      # Setup fs group for file system permissions.
      podSecurityContext.fsGroup = 2000;
      podSecurityContext.fsGroupChangePolicy = "OnRootMismatch";

      # Kubernetes changes permissions of `/data/acme.json`
      # during pod creation to `0660` but traefik needs it
      # to be `0600`.
      deployment.initContainers = [
        {
          name = "volume-permissions";
          image = "busybox:latest";
          command = [
            "sh"
            "-c"
            "touch /data/acme.json; chmod -v 600 /data/acme.json"
          ];
          volumeMounts = [
            {
              mountPath = "/data";
              name = "data";
            }
          ];
        }
      ];

      # Traefik needs to get credentials for cloudflare API.
      # This secret needs to be created before deploying this
      # application out of band.
      # Key name is `CF_DNS_API_TOKEN`.
      envFrom = [
        {
          secretRef.name = "acme-env";
        }
      ];
    }
    cfg.values;
in {
  options.networking.traefik = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    ingressClassName = mkOption {
      type = types.str;
      default = "traefik";
      description = "Name of the ingress class to create.";
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    applications.traefik = {
      inherit namespace;

      helm.releases.traefik = {
        inherit values;
        chart = charts.traefik.traefik;
      };

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
                app.kubernetes.io/name: traefik
            policyTypes:
            - Ingress
            ingress:
            - from:
              - namespaceSelector:
                  matchLabels:
                    kubernetes.io/metadata.name: tailscale
              ports:
              - protocol: TCP
                port: 8000
              - protocol: TCP
                port: 8443
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
                app.kubernetes.io/name: traefik
            egress:
            - toEntities:
              - kube-apiserver
              toPorts:
              - ports:
                - port: "6443"
                  protocol: TCP
        ''

        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-world-egress
            namespace: ${namespace}
          spec:
            endpointSelector:
              matchLabels:
                app.kubernetes.io/name: traefik
            egress:
            # Enable DNS proxying
            - toEndpoints:
              - matchLabels:
                 "k8s:io.kubernetes.pod.namespace": kube-system
                 "k8s:k8s-app": kube-dns
              toPorts:
              - ports:
                - port: "53"
                  protocol: ANY
                rules:
                  dns:
                  - matchPattern: "*"
            # Allow HTTPS to cloudflare and let's encrypt
            - toFQDNs:
              - matchName: api.cloudflare.com
              - matchName: acme-v02.api.letsencrypt.com
              toPorts:
              - ports:
                - port: "443"
                  protocol: TCP
            # Allow DNS lookups with cloudflare
            - toFQDNs:
              - matchPattern: "*.ns.cloudflare.com"
              toPorts:
              - ports:
                - port: "53"
                  protocol: UDP
        ''

        # Load SOPS encrypted secret
        (builtins.readFile ./traefik-secret.sops.yaml)
      ];

      # Patch SOPS secret to include namespace
      resources = {
        "isindir.github.com/v1alpha3".SopsSecret.traefik-secrets = {
          metadata.namespace = namespace;
        };
      };
    };
  };
}

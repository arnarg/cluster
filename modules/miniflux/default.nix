{config, ...}: let
  inherit (builtins) toJSON;

  namespace = "miniflux";

  labels = {
    "app.kubernetes.io/name" = "miniflux";
  };
in {
  applications.miniflux = {
    inherit namespace;
    createNamespace = true;

    resources = {
      # Make sure the SOPS secret has correct namespace
      "isindir.github.com/v1alpha3".SopsSecret.miniflux-secrets = {
        metadata.namespace = namespace;
      };
    };

    yamls = let
      port = toString 8080;
    in [
      ''
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: miniflux
          namespace: ${namespace}
          labels: ${toJSON labels}
        spec:
          replicas: 1
          selector:
            matchLabels: ${toJSON labels}
          template:
            metadata:
              labels: ${toJSON labels}
            spec:
              containers:
              - name: miniflux
                image: ghcr.io/miniflux/miniflux:2.0.50-distroless
                ports:
                - containerPort: ${port}
                  name: http
                env:
                - name: DATABASE_URL
                  valueFrom:
                    secretKeyRef:
                      name: miniflux-creds
                      key: databaseConn
                - name: ADMIN_USERNAME
                  valueFrom:
                    secretKeyRef:
                      name: miniflux-creds
                      key: adminUser
                - name: ADMIN_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: miniflux-creds
                      key: adminPassword
                - name: LISTEN_ADDR
                  value: 0.0.0.0:${port}
                - name: RUN_MIGRATIONS
                  value: "1"
                - name: CREATE_ADMIN
                  value: "1"
      ''

      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: miniflux
          namespace: ${namespace}
        spec:
          type: ClusterIP
          selector: ${toJSON labels}
          ports:
          - name: http
            port: 80
            protocol: TCP
            targetPort: ${port}
      ''

      ''
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: miniflux
          namespace: ${namespace}
        spec:
          ingressClassName: ${config.networking.traefik.ingressClassName}
          rules:
          - host: reader.${config.networking.domain}
            http:
              paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: miniflux
                    port:
                      name: http
      ''

      ''
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: allow-traefik-ingress
          namespace: ${namespace}
        spec:
          podSelector:
            matchLabels: ${toJSON labels}
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
                port: ${port}
      ''

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

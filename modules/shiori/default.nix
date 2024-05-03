{
  lib,
  config,
  ...
}: let
  inherit (builtins) toJSON;

  namespace = "shiori";

  labels = {"app.kubernetes.io/name" = "shiori";};
in {
  applications.shiori = {
    inherit namespace;
    createNamespace = true;

    resources = {
      # Persitent volume for shiori.
      v1.PersistentVolumeClaim.shiori.spec = {
        metadata.namespace = namespace;
        spec = {
          storageClassName = config.storage.csi.nfs.storageClassName;
          volumeMode = "FileSystem";
          accessModes = ["ReadWriteOnce"];
          resources.requests.storage = "10Gi";
        };
      };

      # Make sure the SOPS secret has correct namespace
      "isindir.github.com/v1alpha3".SopsSecret.shiori-secrets = {
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
          name: shiori
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
              - name: shiori
                image: ghcr.io/go-shiori/shiori:v1.5.5
                args:
                - serve
                - --address
                - 0.0.0.0
                - --port
                - "${port}"
                ports:
                - containerPort: ${port}
                  name: http
                env:
                - name: SHIORI_DIR
                  value: /data
                - name: SHIORI_DBMS
                  value: postgresql
                - name: SHIORI_PG_USER
                  valueFrom:
                    secretKeyRef:
                      name: shiori-creds
                      key: dbUser
                - name: SHIORI_PG_PASS
                  valueFrom:
                    secretKeyRef:
                      name: shiori-creds
                      key: dbPass
                - name: SHIORI_PG_NAME
                  valueFrom:
                    secretKeyRef:
                      name: shiori-creds
                      key: dbName
                - name: SHIORI_PG_HOST
                  valueFrom:
                    secretKeyRef:
                      name: shiori-creds
                      key: dbHost
                - name: SHIORI_PG_PORT
                  valueFrom:
                    secretKeyRef:
                      name: shiori-creds
                      key: dbPort
                volumeMounts:
                - mountPath: /data
                  name: data
              securityContext:
                fsGroup: 2000
              volumes:
              - name: data
                persistentVolumeClaim:
                  claimName: shiori
      ''

      ''
        apiVersion: v1
        kind: Service
        metadata:
          name: shiori
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
          name: shiori
          namespace: ${namespace}
        spec:
          ingressClassName: ${config.networking.traefik.ingressClassName}
          rules:
          - host: shiori.${config.networking.domain}
            http:
              paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: shiori
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
          name: allow-https-world-egress
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
      (builtins.readFile ./shiori-secret.sops.yaml)
    ];
  };
}

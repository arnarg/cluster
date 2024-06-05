{charts, ...}: let
  namespace = "sops";
in {
  applications.sops-secrets-operator = {
    inherit namespace;
    createNamespace = true;

    helm.releases.sops = {
      chart = charts.isindir.sops-secrets-operator;

      values = {
        # Mount secret with age keys to operator pod.
        secretsAsFiles = [
          {
            name = "keys";
            mountPath = "/var/lib/sops/age";
            # Secret created manually out of band.
            secretName = "age-keys";
          }
        ];

        # Tell the operator pod where to read age keys.
        extraEnv = [
          {
            name = "SOPS_AGE_KEY_FILE";
            value = "/var/lib/sops/age/key.txt";
          }
        ];
      };
    };

    # Network policies.
    yamls = [
      ''
        apiVersion: cilium.io/v2
        kind: CiliumNetworkPolicy
        metadata:
          name: allow-kube-apiserver-egress
          namespace: ${namespace}
        spec:
          endpointSelector:
            matchLabels:
              app.kubernetes.io/name: sops-secrets-operator
          egress:
          - toEntities:
            - kube-apiserver
            toPorts:
            - ports:
              - port: "6443"
                protocol: TCP
      ''
    ];

    resources = {
      "apps/v1".Deployment.sops-sops-secrets-operator = {
        metadata.namespace = namespace;
      };
      v1.ServiceAccount.sops-sops-secrets-operator = {
        metadata.namespace = namespace;
      };
    };
  };
}

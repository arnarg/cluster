{lib, ...}: let
  chart = lib.helm.downloadHelmChart {
    repo = "https://isindir.github.io/sops-secrets-operator/";
    chart = "sops-secrets-operator";
    version = "0.17.4";
    chartHash = "sha256-gkWySGFVuF4GOFExbJPu4W4KU9YBZcfh1U3cJBjvVVo=";
  };

  namespace = "sops";
in {
  applications.sops = {
    inherit namespace;
    createNamespace = true;

    helm.releases.sops = {
      inherit chart;

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
  };
}

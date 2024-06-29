{lib, ...}: {
  imports = [
    ./argocd
    ./cilium
    ./k8s-gateway
    ./miniflux
    ./traefik
    ./nfs
    ./shiori
    ./sops-secrets-operator
    ./tailscale-operator
  ];

  options = with lib; {
    networking.domain = mkOption {
      type = types.str;
    };
  };

  config = {
    nixidy.target.repository = "https://github.com/arnarg/cluster.git";

    nixidy.chartsDir = ../charts;

    nixidy.defaults = {
      syncPolicy.automated.selfHeal = true;
      syncPolicy.automated.prune = true;

      # Many helm chars will render all resources with the
      # following labels.
      # This produces huge diffs when the charts are updated
      # because the values of these labels change each release.
      # Here we add a transformer that strips them out after
      # templating the helm charts in each application.
      helm.transformer = map (lib.kube.removeLabels [
        "app.kubernetes.io/version"
        "helm.sh/chart"
      ]);
    };
  };
}

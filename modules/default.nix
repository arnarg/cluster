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

    nixidy.defaults = {
      syncPolicy.automated.selfHeal = true;
      syncPolicy.automated.prune = true;
    };
  };
}

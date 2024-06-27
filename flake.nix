{
  description = "My ArgoCD configuration with nixidy.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixidy = {
    url = "github:arnarg/nixidy";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.nixhelm = {
    url = "github:farcaller/nixhelm";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixidy,
    nixhelm,
  }: (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
    };
  in {
    nixidyEnvs.prod = nixidy.lib.mkEnv {
      inherit pkgs;
      modules = [
        ./modules
        ./configuration.nix
        {
          nixidy.charts = nixhelm.chartsDerivations.${system};
          nixidy.chartsDir = ./charts;
        }
      ];
    };

    packages = {
      nixidy = nixidy.packages.${system}.default;
      generators.sops = nixidy.packages.${system}.generators.fromCRD {
        name = "sops";
        src = pkgs.fetchFromGitHub {
          owner = "isindir";
          repo = "sops-secrets-operator";
          rev = "0.13.0";
          hash = "sha256-wPGpbmT/KBPKaloDrYOxdsmQqe6FjDBWS+0M/egb5UA=";
        };
        crds = ["config/crd/bases/isindir.github.com_sopssecrets.yaml"];
      };
      generators.cilium = nixidy.packages.${system}.generators.fromCRD {
        name = "cilium";
        src = pkgs.fetchFromGitHub {
          owner = "cilium";
          repo = "cilium";
          rev = "v1.15.6";
          hash = "sha256-oC6pjtiS8HvqzzRQsE+2bm6JP7Y3cbupXxCKSvP6/kU=";
        };
        crds = [
          "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml"
          "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwidenetworkpolicies.yaml"
        ];
      };
    };

    devShells.default = pkgs.mkShell {
      buildInputs = [
        nixidy.packages.${system}.default
        pkgs.sops
      ];
    };
  }));
}

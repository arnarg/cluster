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
      charts = nixhelm.chartsDerivations.${system};
      modules = [
        ./modules
        ./configuration.nix
        {
          nixidy.build.revision =
            if (self ? rev)
            then self.rev
            else self.dirtyRev;
        }
      ];
    };

    packages = {
      nixidy = nixidy.packages.${system}.default;
      generators = {
        sops = nixidy.packages.${system}.generators.fromCRD {
          name = "sops";
          src = pkgs.fetchFromGitHub {
            owner = "isindir";
            repo = "sops-secrets-operator";
            rev = "0.13.0";
            hash = "sha256-wPGpbmT/KBPKaloDrYOxdsmQqe6FjDBWS+0M/egb5UA=";
          };
          crds = ["config/crd/bases/isindir.github.com_sopssecrets.yaml"];
        };
        cilium = nixidy.packages.${system}.generators.fromCRD {
          name = "cilium";
          src = pkgs.fetchFromGitHub {
            owner = "cilium";
            repo = "cilium";
            rev = "v1.16.0";
            hash = "sha256-LJrNGHF52hdKCuVwjvGifqsH+8hxkf/A3LZNpCHeR7E=";
          };
          crds = [
            "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml"
            "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwidenetworkpolicies.yaml"
          ];
        };
        tailscale = nixidy.packages.${system}.generators.fromCRD {
          name = "tailscale";
          src = pkgs.fetchFromGitHub {
            owner = "tailscale";
            repo = "tailscale";
            rev = "v1.70.0";
            hash = "sha256-rB/zaJavA3OH1HK7Rfpta/QmQzi0xsEYTvW5JzzTAlI=";
          };
          crds = ["cmd/k8s-operator/deploy/crds/tailscale.com_proxyclasses.yaml"];
        };
        traefik = nixidy.packages.${system}.generators.fromCRD {
          name = "traefik";
          src = pkgs.fetchFromGitHub {
            owner = "traefik";
            repo = "traefik-helm-chart";
            rev = "v28.3.0";
            hash = "sha256-fFmvoal7bpPu+CjAYGg5cAYFqffQ20YKJvwlU8YW5NE=";
          };
          crds = [
            "traefik/crds/traefik.io_ingressroutes.yaml"
            "traefik/crds/traefik.io_ingressroutetcps.yaml"
            "traefik/crds/traefik.io_ingressrouteudps.yaml"
            "traefik/crds/traefik.io_traefikservices.yaml"
          ];
        };
      };
    };

    apps = {
      generate = {
        type = "app";
        program =
          (pkgs.writeShellScript "generate-modules" ''
            set -eo pipefail

            echo "generate sops"
            cat ${self.packages.${system}.generators.sops} > modules/sops-secrets-operator/generated.nix

            echo "generate cilium"
            cat ${self.packages.${system}.generators.cilium} > modules/cilium/generated.nix

            echo "generate tailscale"
            cat ${self.packages.${system}.generators.tailscale} > modules/tailscale-operator/generated.nix

            echo "generate traefik"
            cat ${self.packages.${system}.generators.traefik} > modules/traefik/generated.nix
          '')
          .outPath;
      };

      staticCheck = {
        type = "app";
        program =
          (pkgs.writeShellScript "static-lint-check" ''
            set -eo pipefail

            # Use a fancy jq filter to turn the JSON output
            # into workflow commands for github actions.
            # See: https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-a-warning-message
            if [ "$GITHUB_ACTIONS" = "true" ]; then
              ${pkgs.statix}/bin/statix check -o json . | \
                ${pkgs.jq}/bin/jq -r '.file as $file |
                  .report | map(
                    .severity as $severity |
                    .note as $note |
                    .diagnostics | map(
                      . + {
                        "file": $file,
                        "note": $note,
                        "severity": (
                          if $severity == "Error"
                          then "error"
                          else "warning"
                          end
                        )
                      }
                    )
                  ) |
                  flatten | .[] |
                  "::\(.severity) file=\(.file),line=\(.at.from.line),col=\(.at.from.column),endLine=\(.at.to.line),endColumn=\(.at.to.column),title=\(.note)::\(.message)"
                '
            else
              ${pkgs.statix}/bin/statix check .
            fi
          '')
          .outPath;
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

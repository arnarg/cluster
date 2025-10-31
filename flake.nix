{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixidy,
      nixhelm,
    }:
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        nixidyEnvs.prod = nixidy.lib.mkEnv {
          inherit pkgs;
          charts = nixhelm.chartsDerivations.${system};
          modules = [
            ./modules
            ./configuration.nix
          ];
        };

        packages = {
          nixidy = nixidy.packages.${system}.cli;
          generators = {
            cilium = nixidy.packages.${system}.generators.fromCRD {
              name = "cilium";
              src = pkgs.fetchFromGitHub {
                owner = "cilium";
                repo = "cilium";
                rev = "v1.18.2";
                hash = "sha256-FhXLLppugsdnMo9AiTvch44QtLcNUtj9w5wqE14fo+4=";
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
                rev = "v1.88.2";
                hash = "sha256-pVigC0C6skzO65sx+QO7Rz/p7Q1FTO0Bw4TIwFPG1yY=";
              };
              crds = [ "cmd/k8s-operator/deploy/crds/tailscale.com_proxyclasses.yaml" ];
            };
            onepassword = nixidy.packages.${system}.generators.fromCRD {
              name = "onepassword";
              src = nixhelm.chartsDerivations.${system}."1password".connect;
              crds = [ "crds/onepassworditem-crd.yaml" ];
            };
            traefik = nixidy.packages.${system}.generators.fromCRD {
              name = "traefik";
              src = nixhelm.chartsDerivations.${system}.traefik.traefik;
              crds = [
                "crds/traefik.io_ingressroutes.yaml"
                "crds/traefik.io_ingressroutetcps.yaml"
                "crds/traefik.io_ingressrouteudps.yaml"
                "crds/traefik.io_traefikservices.yaml"
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

                echo "generate onepassword"
                cat ${self.packages.${system}.generators.onepassword} > modules/1password-connect/generated.nix

                echo "generate cilium"
                cat ${self.packages.${system}.generators.cilium} > modules/cilium/generated.nix

                echo "generate tailscale"
                cat ${self.packages.${system}.generators.tailscale} > modules/tailscale-operator/generated.nix

                echo "generate traefik"
                cat ${self.packages.${system}.generators.traefik} > modules/traefik/generated.nix
              '').outPath;
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
              '').outPath;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            nixidy.packages.${system}.default
          ];
        };
      }
    ));
}

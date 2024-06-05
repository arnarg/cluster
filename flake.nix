{
  description = "My ArgoCD configuration with nixidy.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.nixidy = {
    url = "github:arnarg/nixidy";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixidy,
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
          nixidy.chartsDir = ./charts;
        }
      ];
    };

    packages.nixidy = nixidy.packages.${system}.default;

    devShells.default = pkgs.mkShell {
      buildInputs = [
        nixidy.packages.${system}.default
        pkgs.sops
      ];
    };
  }));
}

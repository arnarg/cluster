{ lib, ... }:
{
  templates.webApplication = {
    options = with lib; {
      image = mkOption {
        type = lib.types.str;
        description = "The image to use in the web application deployment";
      };
      replicas = mkOption {
        type = lib.types.int;
        default = 1;
        description = "The number of replicas for the web application deployment.";
      };
      port = mkOption {
        type = lib.types.port;
        default = 8080;
        description = "The web application's port.";
      };
      env = mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
        description = "Environment variables to add to the web application's conainer.";
      };
      ingress = {
        enable = mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether or not to enable an ingress for the web application.";
        };
        ingressClassName = mkOption {
          type = lib.types.str;
          description = "The ingressClassName to use.";
        };
        host = mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "The application's ingress host. Set to null to disable ingress.";
        };
      };
    };

    output =
      {
        name,
        config,
        ...
      }:
      let
        cfg = config;
        appLabels = {
          "app.kubernetes.io/name" = name;
        };
      in
      {
        deployments."${name}" = {
          metadata.labels = appLabels;
          spec = {
            replicas = cfg.replicas;
            selector.matchLabels = appLabels;
            template = {
              metadata.labels = appLabels;
              spec.containers."${name}" = {
                inherit (cfg) env;
                image = cfg.image;
                ports."http".containerPort = cfg.port;
              };
            };
          };
        };

        services."${name}".spec = {
          type = "ClusterIP";
          selector = appLabels;
          ports.http = {
            port = 80;
            targetPort = cfg.port;
            protocol = "TCP";
          };
        };

        ingresses = lib.mkIf cfg.ingress.enable {
          "${name}".spec = {
            inherit (cfg.ingress) ingressClassName;

            rules = [
              {
                host = cfg.ingress.host;
                http.paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend.service = {
                      inherit name;
                      port.name = "http";
                    };
                  }
                ];
              }
            ];
          };
        };
      };
  };
}

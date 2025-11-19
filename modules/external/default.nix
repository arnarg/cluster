{ config, ... }:
let
  namespace = "external";
in
{
  applications.external = {
    inherit namespace;
    createNamespace = true;

    resources = {
      services.lab.spec = {
        ports = [
          {
            name = "https";
            port = 443;
            targetPort = 443;
          }
        ];
      };

      endpointSlices.lab = {
        metadata.labels."kubernetes.io/service-name" = "lab";
        addressType = "FQDN";
        endpoints = [
          {
            addresses = [ "lab.codedbearder.com" ];
            conditions.ready = true;
          }
        ];
        ports = [
          {
            name = "https";
            port = 443;
          }
        ];
      };

      ingresses.lab.spec = {
        inherit (config.networking.traefik) ingressClassName;

        rules = [
          {
            host = "lab.${config.networking.domain}";
            http.paths = [
              {
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "lab";
                  port.name = "https";
                };
              }
            ];
          }
        ];
      };

      services.tm.spec.ports = [
        {
          name = "http";
          port = 80;
          targetPort = 9091;
        }
      ];

      endpointSlices.tm = {
        metadata.labels."kubernetes.io/service-name" = "tm";
        addressType = "FQDN";
        endpoints = [
          {
            addresses = [ "lab.codedbearder.com" ];
            conditions.ready = true;
          }
        ];
        ports = [
          {
            name = "http";
            port = 9091;
          }
        ];
      };

      ingresses.tm.spec = {
        inherit (config.networking.traefik) ingressClassName;

        rules = [
          {
            host = "tm.${config.networking.domain}";
            http.paths = [
              {
                path = "/";
                pathType = "Prefix";
                backend.service = {
                  name = "tm";
                  port.name = "http";
                };
              }
            ];
          }
        ];
      };
    };
  };
}

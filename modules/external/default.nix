{ config, ... }:
let
  namespace = "external";
in
{
  applications.external = {
    inherit namespace;
    createNamespace = true;

    resources = {
      services.tm.spec.ports = [
        {
          name = "http";
          port = 80;
          targetPort = 9091;
        }
      ];

      endpointSlices.tm = {
        metadata.labels."kubernetes.io/service-name" = "tm";
        addressType = "IPv4";
        endpoints = [
          {
            addresses = [ "192.168.0.10" ];
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

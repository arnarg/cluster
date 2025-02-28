{charts, ...}: let
  namespace = "1password";
in {
  nixidy.resourceImports = [
    # Hacky way of introducing nice to have
    # helpers into applications.*
    ./secrets.nix
    ./generated.nix
  ];

  applications."1password-connect" = {
    inherit namespace;
    createNamespace = true;

    helm.releases."1password-connect" = {
      chart = charts."1password".connect;

      # Chart includes tests
      extraOpts = ["--skip-tests"];

      values = {
        # Set service type to ClusterIP
        connect.serviceType = "ClusterIP";

        # Set resource requests
        connect.api.resources.requests.cpu = "200m";

        # Deploy the operator
        operator.create = true;
      };
    };

    resources = {
      ciliumNetworkPolicies = {
        # Allow 1password-connect operator pod to access kube-apiserver
        allow-kube-apiserver-egress.spec = {
          endpointSelector.matchLabels = {
            name = "onepassword-connect";
            "app.kubernetes.io/component" = "operator";
          };
          egress = [
            {
              toEntities = ["kube-apiserver"];
              toPorts = [
                {
                  ports = [
                    {
                      port = "6443";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };

        # Allow 1password-connect operator to talk to 1password-connect
        allow-connect-operator.spec = {
          endpointSelector.matchLabels = {
            app = "onepassword-connect";
            "app.kubernetes.io/component" = "connect";
          };
          ingress = [
            {
              fromEndpoints = [
                {
                  matchLabels = {
                    name = "onepassword-connect";
                    "app.kubernetes.io/component" = "operator";
                  };
                }
              ];
              toPorts = [
                {
                  ports = [
                    {port = "8080";}
                  ];
                }
              ];
            }
          ];
        };

        # Allow 1password-connect to talk to 1password API
        allow-world-egress.spec = {
          endpointSelector.matchLabels = {
            app = "onepassword-connect";
            "app.kubernetes.io/component" = "connect";
          };
          egress = [
            # Enable DNS proxying
            {
              toEndpoints = [
                {
                  matchLabels = {
                    "k8s:io.kubernetes.pod.namespace" = "kube-system";
                    "k8s:k8s-app" = "kube-dns";
                  };
                }
              ];
              toPorts = [
                {
                  ports = [
                    {
                      port = "53";
                      protocol = "ANY";
                    }
                  ];
                  rules.dns = [
                    {matchPattern = "*";}
                  ];
                }
              ];
            }
            # Allow HTTPS to my.1password.com
            {
              toFQDNs = [
                {matchName = "my.1password.com";}
              ];
              toPorts = [
                {
                  ports = [
                    {
                      port = "443";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };
      };
    };
  };
}

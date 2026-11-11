{
  lib,
  charts,
  generators,
  ...
}:
let
  namespace = "1password";
in
{
  nixidy.applicationImports = [
    (generators.fromChartCRDModule {
      name = "onepassword";
      chart = charts."1password".connect;
      kindFilter = [ "OnePasswordItem" ];
    })
  ];

  # These secrets are deployed manually
  nixidy.validation.references.ignore = [
    {
      kind = "Secret";
      name = "op-credentials";
    }
    {
      kind = "Secret";
      name = "onepassword-token";
    }
  ];

  templates.opSecret = {
    options = with lib; {
      vault = mkOption {
        type = types.str;
        default = "Cluster";
      };
      itemName = mkOption {
        type = types.str;
      };
    };

    output =
      {
        name,
        config,
        ...
      }:
      {
        onePasswordItems."${name}".spec = {
          itemPath = "vaults/${config.vault}/items/${config.itemName}";
        };
      };
  };

  applications."1password-connect" = {
    inherit namespace;
    createNamespace = true;

    helm.releases."1password-connect" = {
      chart = charts."1password".connect;

      # Chart includes tests
      extraOpts = [ "--skip-tests" ];

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
      # Let the built-in `view` ClusterRole read OnePasswordItems (they only hold item paths).
      clusterRoles.onepassword-aggregate-to-view = {
        metadata.labels."rbac.authorization.k8s.io/aggregate-to-view" = "true";
        rules = [
          {
            apiGroups = [ "onepassword.com" ];
            resources = [ "*" ];
            verbs = [
              "get"
              "list"
              "watch"
            ];
          }
        ];
      };

      ciliumNetworkPolicies = {
        # Allow 1password-connect operator pod to access kube-apiserver
        allow-kube-apiserver-egress.spec = {
          endpointSelector.matchLabels = {
            name = "onepassword-connect";
            "app.kubernetes.io/component" = "operator";
          };
          egress = [
            {
              toEntities = [ "kube-apiserver" ];
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
                    { port = "8080"; }
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
                    { matchPattern = "*"; }
                  ];
                }
              ];
            }
            # Allow HTTPS to the 1Password API and the notifier (b5n)
            {
              toFQDNs = [
                { matchName = "my.1password.com"; }
                { matchName = "b5n.1password.com"; }
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

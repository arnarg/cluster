{charts, ...}: let
  namespace = "1password";
in {
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
  };
}

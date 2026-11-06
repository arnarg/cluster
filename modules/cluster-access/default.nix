_:
let
  namespace = "cluster-access";

  readOnly = [
    "get"
    "list"
    "watch"
  ];

  bindTo = role: {
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io";
      kind = "ClusterRole";
      name = role;
    };
    subjects = [
      {
        kind = "ServiceAccount";
        name = "incident-debugger";
        inherit namespace;
      }
    ];
  };
in
{
  # Read-only access to the cluster for debugging during incidents.
  # Every change must go through this GitOps repo, so nothing here
  # grants write access, exec, port-forward, ephemeral containers,
  # the node proxy or Secrets.
  #
  # Namespaced resources and custom resources come from the
  # built-in `view` ClusterRole. Apps owning CRDs add their
  # custom resources to it with `aggregate-to-view` ClusterRoles.
  applications.cluster-access = {
    inherit namespace;
    createNamespace = true;

    resources = {
      serviceAccounts.incident-debugger = { };

      # Long-lived token populated by the cluster's token controller.
      # Read it with:
      #   kubectl -n cluster-access get secret incident-debugger-token \
      #     -o jsonpath='{.data.token}' | base64 -d
      # Delete the Secret to revoke it; Argo CD recreates it with a new token.
      secrets.incident-debugger-token = {
        metadata.annotations."kubernetes.io/service-account.name" = "incident-debugger";
        type = "kubernetes.io/service-account-token";
      };

      # Cluster-scoped and other resources useful for debugging
      # that `view` doesn't include.
      clusterRoles.incident-debugger.rules = [
        {
          apiGroups = [ "" ];
          resources = [
            "nodes"
            "persistentvolumes"
          ];
          verbs = readOnly;
        }
        {
          apiGroups = [ "storage.k8s.io" ];
          resources = [
            "storageclasses"
            "csidrivers"
            "csinodes"
            "volumeattachments"
          ];
          verbs = readOnly;
        }
        {
          apiGroups = [ "networking.k8s.io" ];
          resources = [ "ingressclasses" ];
          verbs = readOnly;
        }
        {
          apiGroups = [ "metrics.k8s.io" ];
          resources = [
            "nodes"
            "pods"
          ];
          verbs = readOnly;
        }
        {
          apiGroups = [ "apiextensions.k8s.io" ];
          resources = [ "customresourcedefinitions" ];
          verbs = readOnly;
        }
        {
          apiGroups = [ "admissionregistration.k8s.io" ];
          resources = [
            "mutatingwebhookconfigurations"
            "validatingwebhookconfigurations"
          ];
          verbs = readOnly;
        }
        {
          apiGroups = [ "rbac.authorization.k8s.io" ];
          resources = [
            "roles"
            "rolebindings"
            "clusterroles"
            "clusterrolebindings"
          ];
          verbs = readOnly;
        }
      ];

      clusterRoleBindings = {
        incident-debugger-view = bindTo "view";
        incident-debugger = bindTo "incident-debugger";
      };
    };
  };
}

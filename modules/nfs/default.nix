{
  lib,
  config,
  ...
}: let
  cfg = config.storage.csi.nfs;

  chart = lib.helm.downloadHelmChart {
    repo = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts";
    chart = "csi-driver-nfs";
    version = "4.5.0";
    chartHash = "sha256-C3ARScgLFPMzNN9fLZMCZ/DrBQajrJVkvtkG6jN6LtM=";
  };

  namespace = "kube-system";

  # Parse default values in the chart
  values = lib.head (lib.kube.fromYAML (builtins.readFile "${chart}/values.yaml"));
in {
  options.storage.csi.nfs = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    storageClassName = mkOption {
      type = types.str;
      default = "nfs-csi";
      description = "Name of the storage class to create for csi-driver-nfs.";
    };
    server = mkOption {
      type = types.str;
      description = "Address of the NFS server to use for the storage class for csi-driver-nfs.";
    };
    share = mkOption {
      type = types.str;
      description = "NFS share path to use for the storage class for csi-driver-nfs.";
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    applications.csi-driver-nfs = {
      inherit namespace;

      helm.releases.csi-driver-nfs = {
        inherit chart values;
      };

      # Network policies
      yamls = [
        ''
          apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: allow-kube-apiserver-egress
            namespace: ${namespace}
          spec:
            description: "Allow snapshot controller to talk to kube-apiserver"
            endpointSelector:
              matchLabels:
                app: snapshot-controller
            egress:
            - toEntities:
              - kube-apiserver
              toPorts:
              - ports:
                - port: "6443"
                  protocol: TCP
        ''
      ];

      # Create a storage class
      resources = {
        "storage.k8s.io/v1".StorageClass.${cfg.storageClassName} = {
          provisioner = values.driver.name;
          parameters.server = cfg.server;
          parameters.share = cfg.share;
          reclaimPolicy = "Retain";
          volumeBindingMode = "Immediate";
          mountOptions = ["nfsvers=4.1"];
        };
      };
    };
  };
}

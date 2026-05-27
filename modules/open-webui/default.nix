{ config, charts, ... }:
{
  applications.open-webui = {
    syncPolicy.syncOptions.createNamespace = true;

    templates.opSecret.openwebui-creds.itemName = "openwebui_creds";

    helm.releases.open-webui = {
      chart = charts.open-webui.open-webui;

      values = {
        ingress = {
          enabled = true;
          class = config.networking.traefik.ingressClassName;
          host = "chat.${config.networking.domain}";
        };

        ollama.enabled = false;

        enableOpenaiApi = false;

        extraEnvVars = [
          {
            name = "DATABASE_TYPE";
            value = "postgresql";
          }
          {
            name = "DATABASE_HOST";
            valueFrom.secretKeyRef = {
              name = "openwebui-creds";
              key = "databaseHost";
            };
          }
          {
            name = "DATABASE_USER";
            valueFrom.secretKeyRef = {
              name = "openwebui-creds";
              key = "databaseUser";
            };
          }
          {
            name = "DATABASE_PASSWORD";
            valueFrom.secretKeyRef = {
              name = "openwebui-creds";
              key = "databasePassword";
            };
          }
          {
            name = "DATABASE_NAME";
            valueFrom.secretKeyRef = {
              name = "openwebui-creds";
              key = "databaseName";
            };
          }
        ];

        persistence = {
          enabled = true;
          storageClass = config.storage.csi.nfs.storageClassName;
          subPath = "openwebui";
        };
      };
    };
  };
}

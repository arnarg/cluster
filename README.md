# arnarg/cluster

GitOps for my Kubernetes cluster defined with [nixidy](https://github.com/arnarg/nixidy).

## Networking

The cluster runs on k3s and uses Cilium for CNI.

### Exposing services

Services are only accessible inside my tailscale tailnet. Using tailscale-operator 2 services are exposed, traefik and k8s_gateway.

[k8s_gateway](https://github.com/ori-edge/k8s_gateway) is a CoreDNS plugin which will resolve the hostname set in Ingresses to the ip or hostname set in `.status.loadBalancer.ingress` of the same `Ingress` object.

[traefik](https://traefik.io/traefik/) proxies all Ingresses and updates their `.status.loadBalancer.ingress` to its own Service's external IP, which is set by tailscale-operator.

With this setup I then just have to set up split DNS in tailscale console to resolve my domain by sending those queries to the address of k8s_gateway. All queries will resolve to traefik's address and it will proxy it forward to the service with the specified hostname in its `Ingress` object.

![Proxy setup diagram](./proxy_setup.drawio.svg)

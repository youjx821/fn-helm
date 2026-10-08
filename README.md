# Fn Project Helm Chart

The [Fn project](http://fnproject.io) is an open source, container native, and cloud agnostic serverless platform. It’s easy to use, supports every programming language, and is extensible and performant.

## Introduction

This chart deploys a fully functioning instance of the [Fn](https://github.com/fnproject/fn) platform on a Kubernetes cluster using the [Helm](https://helm.sh/) package manager.

## Prerequisites

- A Kubernetes cluster >= 1.23 (chart uses `apps/v1`, `networking.k8s.io/v1`)

- Helm >= 3.8 (required for OCI-based sub-chart dependencies)

- persistent volume provisioning support in the underlying infrastructure (for persistent data, see below )

- [Ingress controller](https://kubernetes.github.io/ingress-nginx/deploy/) (e.g. ingress-nginx)

- [Cert manager](https://cert-manager.io/docs/installation/) >= 1.0 (optional, only needed for TLS)

## Preparing chart values

### Minimum configuration

In order to get a working deployment please pay attention to what you have in your chart values.
[Here](fn/values.yaml) is the bare minimum chart configuration to deploy a working Fn cluster.

### Exposing Fn services

#### Ingress controller

If you are installing Fn behind an ingress controller, you'll need to have a single DNS sub-domain that will act as your ingress controllers IP resolution.

Important: An ingress controller works as a proxy, so you can use the ingress IP address as an HTTP proxy:

```bash
curl -x http://<ingress-controller-endpoint>:80 api.fn.internal 
{"goto":"https://github.com/fnproject/fn","hello":"world!"}
```


#### LoadBalancer

In order to natively expose the Fn services, you'll need to modify the Fn API, Runner, and UI service definitions:

 - at `fn_api` node values, modify `fn_api.service.type` from `ClusterIP` to `LoadBalancer`
 - at `fn_lb_runner` node values, modify `fn_lb_runner.service.type` from `ClusterIP` to `LoadBalancer`
 - at `ui` node values, modify `ui.service.type` from `ClusterIP` to `LoadBalancer`


#### DNS names

In an Fn deployment with LoadBalancer service types, you'll need 3 DNS names:

 - one for an API service (i.e., `api.fn.mydomain.com`)
 - one for runner LB service (i.e., `lb.fn.mydomain.com`)
 - one for UI service (i.e., `ui.fn.mydomain.com`)

Upon successful deployment, you'll have three public IP addresses -- one for each service.
However, the IP address for the API and LB services will be identical since they are exposed as a single service.
You'll have two IP addresses, but three DNS names.

Please keep in mind the best way for exposing services is an **ingress controller**.

## Installing the Chart

### Deployment notes for restricted / 2-VM kubeadm clusters

The chart was deployed and verified on a 2-node kubeadm cluster
(AlmaLinux 10, k8s v1.37.1, containerd + docker, flannel):

1. **Registry mirrors** (docker.io unreachable from the VMs):
   - containerd: `/etc/containerd/certs.d/docker.io/hosts.toml` **and**
     `/etc/containerd/certs.d/registry-1.docker.io/hosts.toml` pointing at
     public mirrors (e.g. `https://docker.1ms.run`), then
     `systemctl restart containerd`
   - host docker (used by fn runners to spawn function containers):
     `/etc/docker/daemon.json` with the same `registry-mirrors`
2. **Bitnami images**: use the `bitnamilegacy/*` repositories
   (`postgresql.image.repository=bitnamilegacy/postgresql`,
   `redis.image.repository=bitnamilegacy/redis`).
3. **No ingress controller**: expose services via NodePort
   (`--set ingress.enabled=false --set fn_api.service.type=NodePort
   --set ui.service.type=NodePort`).
4. **Runners** mount the host docker socket, use `hostNetwork` and share
   `/tmp/iofs` (see `fn_runner.*` values) so they can reach the function
   containers created by the host docker daemon. With `hostNetwork`,
   schedule at most one runner per node.
5. Verify: `curl http://<nodeIP>:<apiNodePort>/v2/apps`, then create an app
   + function (image implementing the FDK listener protocol, e.g.
   `fnproject/fn-test-utils:latest` pre-pulled on the worker) and
   `curl -X POST http://<nodeIP>:<lbNodePort>/invoke/<fnID>`.

Clone the fn-helm repo:

```bash
git clone https://github.com/fnproject/fn-helm.git && cd fn-helm
```

Install chart dependencies (PostgreSQL and Redis sub-charts, pulled from the
[Bitnami OCI registry](https://github.com/bitnami/charts)) as declared in
[Chart.yaml](./fn/Chart.yaml):

```bash
helm dependency build fn
```

The default chart will install fn as a private service inside your cluster with ephemeral storage, to configure a public endpoint and persistent storage you should look at [values.yaml](fn/values.yaml) and modify the default settings.
To install the chart with the release name `my-release`:

```bash
helm install my-release fn
```

## Working with Fn 

#### Ingress controller

Please ensure that your ingress controller is running and has a public-facing IP address.
An ingress controller acts as a proxy between your internal and public networks.
Therefore in order to talk to your Fn Deployment, you'll need to set the `HTTP_PROXY` environment variable or use cURL like so:

```bash
curl -x http://<ingress-controller-endpoint>:80 api.fn.internal
{"goto":"https://github.com/fnproject/fn","hello":"world!"}
```

## Uninstalling the Fn Helm Chart

Assuming your release is named `my-release`:

```bash
helm uninstall my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration 

For detailed configuration, please see [default chart values](fn/values.yaml).

 ## Configuring Database Persistence 

Fn persists application data in PostgreSQL. This is configured using the Bitnami PostgreSQL sub-chart.

By default this uses container storage. To configure a persistent volume, set the `postgresql.primary.persistence.*` values in the chart values to that which corresponds to your storage requirements.

e.g. to use an existing persistent volume claim for PostgreSQL storage:

```bash 
helm install testfn --set postgresql.primary.persistence.enabled=true,postgresql.primary.persistence.existingClaim=tc-fn-postgresql fn
```

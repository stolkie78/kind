# Kind Demo with ArgoCD, NGINX Ingress, and Kubernetes Dashboard

This project sets up a **Kind-based Kubernetes cluster** with the following components:

- **NGINX Ingress Controller** (for managing ingress traffic)
- **Kubernetes Dashboard** (for cluster monitoring)
- **ArgoCD** (for GitOps-based application deployment)

## Prerequisites

- Install [Flox](https://flox.dev) (if not already installed)

- Since we are using an **NGINX Ingress Controller**, you can access services directly via **localhost**. Add the following lines to `/etc/hosts`:

```
127.0.0.1 localhost argocd.local dashboard.local
```
For every service you name in the ingress controller a "dns" record must be in place.

- An argocd repo containing deployment. Default is mine at github


## Setup Instructions
1. Clone this repository:

   ```sh
   git clone <repo-url>
   cd kind-demo
   ```

2. Activate the Flox environment:

   ```sh
   flox activate
   ```

   This will automatically run the `setup.sh` script to:
   - Set up a Kind cluster
   - Deploy NGINX Ingress Controller
   - Deploy Kubernetes Dashboard
   - Deploy ArgoCD
   - Apply `applications.yaml` to configure ArgoCD applications

## Accessing Services via Ingress Controller

Since we are using an **NGINX Ingress Controller**, you can access services directly via **localhost**. Add the following lines to `/etc/hosts`:

```
127.0.0.1 localhst argocd.local dashboard.local
```

### Access ArgoCD

Open a browser and go to:

```
https://argocd.local
```

### Access Kubernetes Dashboard

Open a browser and go to:

```
https://dashboard.local
```

## Using ArgoCD

ArgoCD is configured to deploy applications from Git using `applications.yaml`.

### ArgoCD Repository

The ArgoCD application deployments are stored in the following repository:

```
<argocd-repo-url>
```

### Login to ArgoCD

Get the initial admin password:

```sh
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

Login using:

```sh
argocd login argocd.local --username admin --password <PASSWORD>
```

### Deploy Applications via `applications.yaml`

The `setup.sh` script automatically applies `applications.yaml`, which contains ArgoCD application definitions.
If needed, you can manually reapply it:

```sh
kubectl apply -f deployments/argocd/applications.yaml
```

This will make ArgoCD sync applications from the specified Git repository.

## Using the Kubernetes Dashboard

To access the Kubernetes Dashboard:

1. Open a browser and go to:

   ```
   https://dashboard.local
   ```

2. Get the authentication token:

   ```sh
   kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode
   ```

3. Copy the token and paste it into the **Dashboard Login Page**.

## Verifying Deployments

Check if all pods are running:

```sh
kubectl get pods -A
```

Check the deployed applications in ArgoCD:

```sh
argocd app list
```

## Cleanup

To delete the Kind cluster:

```sh
kind delete cluster --name kind-demo
```

---

This setup ensures that your Kubernetes environment is automatically configured when activating the Flox environment, making it easy to manage deployments with ArgoCD and monitor the cluster using the Kubernetes Dashboard.


## ArgoCD
The application.yaml defines an ArgoCD application that makes it possible to add all kinds of applications and deployment. Currently this is the same repo, but in GitOps enviroments this is mostly a kustomize generated environent connect to a pipeline to ensure all tests and checks. For this demo everything in the same repo.
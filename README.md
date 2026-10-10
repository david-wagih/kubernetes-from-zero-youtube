# Kubernetes from Zero

Companion repo for the **Kubernetes from Zero** YouTube playlist. Each folder holds the manifests and code used in one episode, so you can follow along and run everything yourself.

▶️ **[Watch the playlist on YouTube](https://www.youtube.com/watch?v=V_Ojz_GHMAc&list=PLaQNHO-OBKRk)**

## 🎨 Diagrams

All concepts in the series are explained using this Excalidraw board. Keep it open while you watch:

👉 **[Kubernetes from Zero: Excalidraw diagrams](https://link.excalidraw.com/l/3NqPjPnhAl/7Vme2EQnMhM)**

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (Kubernetes in Docker)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Episodes

| # | Topic | Folder | What's inside |
|---|-------|--------|---------------|
| 04 | Pods | [`episode-04-pods`](episode-04-pods) | A working nginx Pod and a broken one (bad image) for debugging |
| 05 | ReplicaSets & Deployments | [`episode-05-replicasets-deployments`](episode-05-replicasets-deployments) | nginx ReplicaSet (3 replicas) and nginx Deployment (2 replicas) |
| 06 | Services | [`episode-06-services`](episode-06-services) | `traefik/whoami` backend + ClusterIP Service |
| 07 | ConfigMaps & Secrets | [`episode-07-configmaps-secrets`](episode-07-configmaps-secrets) | ConfigMap, Secret, a Deployment that consumes both via `envFrom`, and a sample FastAPI app |
| 08 | Storage | [`episode-08-storage`](episode-08-storage) | `emptyDir` Pod, PersistentVolumeClaim, Deployment mounting the PVC |
| 09 | StatefulSets | [`episode-09-statefulsets`](episode-09-statefulsets) | nginx StatefulSet with `volumeClaimTemplates` + headless Service |
| 10 | Ingress | _coming soon_ | |

The [`setup/`](setup) folder has the kind cluster config (1 control plane + 2 workers) used throughout the series.

## Quick start

```bash
# 1. Create the cluster
kind create cluster --config setup/cluster.yaml

# 2. Apply any episode's manifests
kubectl apply -f episode-04-pods/nginx.yaml
kubectl apply -f episode-09-statefulsets/

# 3. Inspect
kubectl get pods -o wide

# 4. Clean up
kubectl delete -f episode-09-statefulsets/
kind delete cluster
```

## Episode notes

### 04: Pods
- `nginx.yaml`: a minimal Pod.
- `nginx_fail.yaml`: uses a non-existent image on purpose. Use `kubectl describe pod broken-nginx` to see `ErrImagePull` / `ImagePullBackOff`.

### 06: Services
Test the Service from inside the cluster:
```bash
kubectl run tmp --rm -it --image=busybox -- wget -qO- http://backend-service
```
Run it a few times. `whoami` prints a different pod hostname as traffic is load-balanced.

### 07: ConfigMaps & Secrets
`secret.yaml` contains **placeholder** values. Replace them with your own base64-encoded credentials:
```bash
echo -n 'your-username' | base64
```
The `app/` folder contains a small FastAPI app and Dockerfile used in the episode.

### 08: Storage
- `pod.yaml`: `emptyDir` volume, which lives only as long as the Pod.
- `pvc.yaml` + `deployment.yaml`: data persists across Pod restarts via a PersistentVolumeClaim.

### 09: StatefulSets
Each replica (`web-0`, `web-1`, `web-2`) gets its own PVC and a stable DNS name through the headless Service, e.g. `web-0.nginx.default.svc.cluster.local`.

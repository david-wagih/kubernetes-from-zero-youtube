# Episode 10: Ingress & Ingress Controllers

Expose two HTTP apps (frontend + backend) through **one** entry point using an Ingress resource and the NGINX Ingress controller, then add host-based routing and HTTPS.

```
                    localhost:80 / :443
                            │
                  ┌─────────▼──────────┐
                  │ ingress-nginx      │  ← Ingress controller (the reverse proxy)
                  │ (control-plane)    │
                  └───┬────────────┬───┘
            /  or app.example.com  /api  or api.example.com
                      │            │
             frontend-service   backend-service
                      │            │
               frontend pods    backend pods
```

## Files

| File | What it is |
|------|------------|
| `cluster.yaml` | kind cluster with ports 80/443 mapped to the control-plane node |
| `applications.yaml` | `frontend` + `backend` Deployments and their ClusterIP Services |
| `ingress.yaml` | Path-based routing: `/` → frontend, `/api` → backend |
| `ingress-host.yaml` | Host-based routing: `app.example.com` / `api.example.com` |
| `ingress-tls.yaml` | Host-based routing + TLS using the `myapp-tls` Secret |
| `generate-cert.sh` | Creates a self-signed cert and the `myapp-tls` Secret |
| `notes.md` | Talking points for the episode |

> ⚠️ **About ingress-nginx:** the community `kubernetes/ingress-nginx` project was retired in March 2026 and its repo is archived. `controller-v1.15.1` is the final release. That's fine for learning on a local kind cluster. For new production clusters, choose a maintained controller or look at Gateway API instead.

---

## Step 1: Create the cluster

```bash
kind create cluster --name ingress --config cluster.yaml
kubectl config current-context   # should print kind-ingress
kubectl get nodes --show-labels | grep ingress-ready
```

`extraPortMappings` forwards `localhost:80` and `localhost:443` on your machine into the **control-plane** container. Whatever listens on ports 80/443 on that node receives the traffic.

## Step 2: Install the NGINX Ingress controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
```

The controller binds `hostPort` 80/443, but only the control-plane node has the port mapping, so pin the controller there:

```bash
kubectl -n ingress-nginx patch deployment ingress-nginx-controller \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"}}}}}'

kubectl -n ingress-nginx rollout status deployment ingress-nginx-controller
kubectl -n ingress-nginx get pods -o wide   # controller should be on ingress-control-plane
kubectl get ingressclass                    # → nginx
```

Before deploying anything, the controller already answers with a 404 (no rules yet):

```bash
curl -i http://localhost/
```

## Step 3: Deploy the applications

```bash
kubectl apply -f applications.yaml
kubectl get pods,svc
```

Both Services are `ClusterIP`, so they can't be reached from outside the cluster yet.

## Step 4: Path-based routing

```bash
kubectl apply -f ingress.yaml
kubectl get ingress
kubectl describe ingress myapp-ingress
```

Test it:

```bash
curl http://localhost/            # Hello from the FRONTEND
curl http://localhost/api         # Hello from the BACKEND (api)
curl http://localhost/api/users   # BACKEND: Prefix matches path segments
curl http://localhost/apiv2       # FRONTEND: /apiv2 is NOT under /api
```

> If you get `failed calling webhook "validate.nginx.ingress.kubernetes.io"`, the controller's admission webhook isn't ready yet. Wait a few seconds and apply again.

## Step 5: Host-based routing

First, point the demo hostnames at your machine so the browser and curl can use them like real domains:

```bash
echo "127.0.0.1 app.example.com api.example.com" | sudo tee -a /etc/hosts
```

Now `app.example.com` resolves to `127.0.0.1` → kind's port mapping → the Ingress controller. In production, real DNS does this job: it must point the names at the controller's external address. An Ingress never creates DNS records.

`ingress-host.yaml` uses the same name (`myapp-ingress`), so applying it **replaces** the path-based rules:

```bash
kubectl apply -f ingress-host.yaml

curl http://app.example.com/   # FRONTEND
curl http://api.example.com/   # BACKEND
curl -i http://localhost/      # 404: no rule for host "localhost"
```

Same IP, same port, different answers. The controller picks the rule from the HTTP `Host` header, which curl and the browser fill in from the URL. You can see it by faking the header yourself:

```bash
curl -H "Host: api.example.com" http://localhost/   # BACKEND
```

Open http://app.example.com and http://api.example.com in the browser too.

## Step 6: HTTPS / TLS termination

Create a self-signed certificate and store it in a TLS Secret (callback to Episode 7):

```bash
./generate-cert.sh
kubectl get secret myapp-tls
kubectl describe secret myapp-tls   # type: kubernetes.io/tls, keys tls.crt + tls.key
```

Apply the TLS Ingress:

```bash
kubectl apply -f ingress-tls.yaml
```

Test it:

```bash
# HTTP now redirects to HTTPS (308)
curl -i http://app.example.com/

# HTTPS, trusting our self-signed cert
curl --cacert certs/tls.crt https://app.example.com/
curl --cacert certs/tls.crt https://api.example.com/

# Without --cacert, curl refuses: the cert isn't signed by a trusted CA
curl https://app.example.com/

# See which certificate the controller served
curl -v --cacert certs/tls.crt https://app.example.com/ 2>&1 | grep -E "subject:|SSL connection"
```

The hostname is sent in the TLS handshake (SNI), so the controller knows which certificate to present before any HTTP is exchanged. Hit it with a name that has no TLS rule and you get the controller's default certificate:

```bash
curl -vk https://localhost/ 2>&1 | grep -E "subject:|HTTP/"
# subject: ... Kubernetes Ingress Controller Fake Certificate  → 404
```

In the browser, https://app.example.com shows a certificate warning because the cert is self-signed. Click through to see the page and inspect the certificate (issued to `app.example.com`). In real clusters, tools like cert-manager issue trusted certificates automatically.

## Step 7: Troubleshooting

Debug one hop at a time:

```
Client → Controller reachable? → Rule matched? → Service exists? → Endpoints ready? → App responds?
```

```bash
kubectl get ingress
kubectl describe ingress myapp-ingress
kubectl get svc
kubectl get endpointslices
kubectl get pods -o wide
kubectl get ingressclass
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=20
```

**Break it on purpose: 503 (no endpoints)**

```bash
kubectl scale deployment backend --replicas=0
curl -i --cacert certs/tls.crt https://api.example.com/                    # 503
kubectl get endpointslices -l kubernetes.io/service-name=backend-service   # no ready endpoints
kubectl scale deployment backend --replicas=2
```

**Break it on purpose: 404 (no matching rule)**

```bash
curl -i -H "Host: wrong.example.com" http://localhost/   # 404 from the controller
```

| Symptom | What to check |
|---------|---------------|
| Connection refused | Controller not running on the control-plane node (did you run the patch?), or port 80/443 already in use on your machine |
| Could not resolve host | Missing `/etc/hosts` entry (or real DNS in production) |
| 404 | Host or path doesn't match any rule, or the app itself returns 404 |
| 503 | Service has no ready endpoints: wrong selector, pods down, scaled to 0 |
| Ingress ignored | Missing/wrong `ingressClassName` (check `kubectl get ingressclass`) |
| Wrong app answers | Overlapping rules, check host and path order |

## Clean up

```bash
kind delete cluster --name ingress
sudo sed -i '' '/app.example.com api.example.com/d' /etc/hosts
```

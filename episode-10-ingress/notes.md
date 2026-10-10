# Episode 10 notes: Ingress (series finale)

Target length: 35–45 min, about half hands-on.

## 1. Cold open: the problem from Episode 6

> We have a frontend and a backend inside Kubernetes, both behind Services. A user opens `myapp.com`. How does Kubernetes know whether the request goes to the frontend or the backend?

Requirements:
- `myapp.com/` → frontend
- `myapp.com/api` → backend

## 2. Service types recap

| Type | Purpose |
|------|---------|
| ClusterIP | Internal only |
| NodePort | Opens a port on every node |
| LoadBalancer | Asks the cloud for an external load balancer |

One LoadBalancer per app means more cost and more things to manage. We want **one** HTTP(S) entry point that routes by host and path.

## 3. What is an Ingress?

> An Ingress is a Kubernetes API resource that defines rules for routing HTTP and HTTPS traffic to Services inside a cluster.

HTTP/HTTPS only. Not for raw TCP like PostgreSQL.

## 4. Ingress vs Ingress controller (most important part)

- **Ingress resource**: the configuration (desired routing rules).
- **Ingress controller**: the actual reverse proxy that watches Ingress objects, configures itself, and forwards traffic.

An Ingress without a controller does nothing. **IngressClass** says which controller handles which Ingress (`ingressClassName: nginx`).

Demo moment: `curl localhost` right after installing the controller returns NGINX's 404. The proxy is running but has no rules yet.

**2026 note:** community ingress-nginx was retired in March 2026 (repo archived, final release v1.15.1). The Ingress API still exists and other controllers implement it. We use ingress-nginx here because it's the classic way to learn, not as a production recommendation.

## 5. Routing rules and pathType

- Path-based: one host, many paths.
- Host-based: different hostnames.

| pathType | Meaning |
|----------|---------|
| Exact | Exact path only |
| Prefix | Prefix by path segments: `/api` matches `/api/users`, not `/apiv2` |
| ImplementationSpecific | Up to the controller |

Ingress does **not** rewrite paths. `/api/users` arrives at the backend as `/api/users`. Our demo apps answer on every path, so no rewrite is needed.

## 6. Hands-on (see README steps 1–4)

Why `extraPortMappings` instead of a LoadBalancer: kind nodes are Docker containers. We forward host ports 80/443 into the control-plane container, and the controller listens there with `hostPort`. That's also why we pin the controller to that node with the `ingress-ready=true` label.

Walk through `ingress.yaml`:
1. `ingressClassName`: which controller
2. `rules`: what to match
3. `path` + `pathType`: how to match
4. `backend.service`: where to send it

The Ingress doesn't create Pods or Services. Those come from `applications.yaml`, like in earlier episodes.

Success moment: two apps, one entry point, no per-app load balancer.

## 7. Host-based routing (README step 5)

`/etc/hosts` plays the role of DNS locally: both names point to 127.0.0.1, so the request always reaches the same controller. The controller then picks the rule from the HTTP `Host` header (show it with `curl -H "Host: api.example.com" http://localhost/`). No domain purchase needed. In production real DNS must point to the controller. Ingress does not manage DNS.

## 8. HTTPS / TLS (README step 6)

```
Browser ──HTTPS──▶ Ingress controller ──HTTP──▶ Service ──▶ Pod
```

- TLS cert + key live in a Secret of type `kubernetes.io/tls` (Episode 7 callback).
- `spec.tls` lists hosts + `secretName`.
- The controller terminates TLS. Apps keep speaking plain HTTP.
- ingress-nginx redirects HTTP → HTTPS automatically once TLS is configured (308).
- SNI: the hostname in the TLS handshake picks the cert. No match means the controller's fake default cert.
- Production: cert-manager + Let's Encrypt. Out of scope here.

## 9. Troubleshooting (README step 7)

Mental model: Client → controller reachable → rule matched → Service exists → endpoints ready → app responds.

Live breaks: scale backend to 0 → 503. Wrong Host → 404.

## 10. Gateway API (short)

The Ingress API is frozen. New features go into Gateway API:
- **GatewayClass**: which implementation (like IngressClass)
- **Gateway**: the entry point / listeners (owned by platform team)
- **HTTPRoute**: routing rules (owned by app teams)

Clearer ownership split and richer routing (header matching, traffic splitting, etc.). Docs: https://gateway-api.sigs.k8s.io/

## 11. Recap: all 10 episodes

- 1–3: why Kubernetes, cluster architecture, kind setup
- 4–5: Pods, ReplicaSets, Deployments
- 6: Services and discovery
- 7: ConfigMaps and Secrets (used again today for TLS)
- 8: Volumes, PVs, PVCs
- 9: StatefulSets
- 10: Ingress and external HTTP routing

## 12. Closing

> We've reached the end of Kubernetes From Zero. We started by asking why Kubernetes exists. Today we know how to run applications, scale them, connect them, configure them, give them storage, and expose them to users outside the cluster.
>
> This is only the beginning: health checks, resource limits, observability, security, Helm, autoscaling, production operations. But you now have the foundation to understand all of it.

Ask viewers what they want next.

## Recording checklist

- [ ] Why Services alone don't solve HTTP routing
- [ ] Ingress vs controller + IngressClass
- [ ] ingress-nginx retirement note
- [ ] kind cluster with extraPortMappings
- [ ] Install + pin ingress-nginx, show 404 with no rules
- [ ] Deploy frontend/backend
- [ ] Path-based routing (`/`, `/api`, `/apiv2` pathType demo)
- [ ] Host-based routing via /etc/hosts (curl + browser), explain the `Host` header
- [ ] TLS Secret + HTTPS + HTTP→HTTPS redirect
- [ ] Break it: 503 and 404
- [ ] Gateway API intro
- [ ] Recap + close the playlist

# Kubernetes

The same blue and green slots, expressed as two Deployments. One Service selects only one color. Moving traffic is a label change. Scaling, restarts, and health are the cluster's job.

```bash
docker build -t platform-lab:local ../../app
kubectl apply -k .
kubectl -n platform-lab rollout status deployment/platform-app-blue
./scripts/switch.sh green
./scripts/switch.sh blue
```

`imagePullPolicy: IfNotPresent` uses a local image. On a multi-node cluster, load that image onto every node first, or push it to a registry and change the image field.

The HorizontalPodAutoscaler needs metrics-server. The Ingress expects an ingress-nginx controller and a DNS name or hosts entry for `platform.local`.

## What each object is for

| Object | Why it is here |
| --- | --- |
| Deployment (two of them) | Desired replica count, rolling replace inside one color, and the version env var |
| Service | Stable address. The selector is the traffic switch |
| readinessProbe | A pod that fails `/health` is removed from the Service. Users do not see it |
| livenessProbe | A wedged process is restarted. It is not used to decide traffic |
| resources | The scheduler and the HPA both need requests. Limits keep one pod from taking the node |
| HPA | Adds pods when CPU stays above 70% of the request, between 2 and 5 replicas |
| PodDisruptionBudget | A node drain must leave at least one pod of that color up |
| NetworkPolicy | Application pods accept traffic only from the ingress namespace, and they may only talk to DNS |
| Ingress | HTTP hostname in front of the Service |

The container runs as UID 10001, with a read-only root filesystem and no added capabilities. That matches the user in the Dockerfile.

## Release

Change `APP_VERSION` (and the image tag, once you publish images) on the color that is **not** selected by the Service. Wait until `kubectl rollout status` reports that color is done and its pods are Ready. Then change `color` in `service.yaml` and apply, or run `./scripts/switch.sh`.

`switch.sh` patches the live Service. If you later adopt auto-sync from Git, that patch gets reverted unless the Git copy of `service.yaml` changed too. Project 07 is that distinction.

## Concepts this makes easy to discuss

- **Readiness versus liveness.** Readiness protects users. Liveness restarts the process. Using liveness for a slow dependency restart-loops the pod.
- **Requests versus limits.** Requests place the pod. The HPA percentage is computed from requests, not from limits.
- **PDB versus HPA.** The autoscaler may want to remove a pod while a drain also wants to evict one. `minAvailable: 1` with `minReplicas: 2` leaves room for a voluntary disruption.
- **NetworkPolicy default.** Once any policy selects the pod, traffic that is not allowed is denied. The egress rule exists so DNS still works.
- **Selectors are the deploy.** The Service does not know about versions. It knows about labels. Blue-green on Kubernetes is a selector change between two ready Deployments.

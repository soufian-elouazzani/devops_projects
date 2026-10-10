# Blue-green deployment

Two copies of the application run at the same time. Nginx sends every user request to one of them. A release updates the idle copy, checks `/health`, and only then reloads Nginx onto that copy. Rollback is the same reload, pointed back at the copy you just left.

```bash
./scripts/up.sh
./scripts/status.sh
./scripts/deploy.sh 1.4.0
./scripts/status.sh
./scripts/rollback.sh
./scripts/down.sh
```

| Port | What it is |
| --- | --- |
| 8080 | The proxy. This is the only port a user should use |
| 8081 | Blue, reached directly so you can see it before it is live |
| 8082 | Green, same idea |

The scripts judge `/health` from inside the Docker network, then print what the proxy is serving. That still works if the host firewall drops traffic into the Docker bridge. `status.sh` says so when port 8080 does not answer from the host.

`deploy.sh` refuses to switch when the new copy does not answer `/health` within 30 seconds. The old copy keeps the traffic. That health gate is the whole point of the script. A deploy that always switches is just a restart with extra steps.

## What you should see

After `up.sh`, the proxy and blue both report `"color": "blue"`. After `deploy.sh 1.4.0`, the proxy and green report `"version": "1.4.0"` and blue is still the previous version. After `rollback.sh`, the proxy reports blue again and green is still up, idle.

## How this maps to the other projects

| This script | On AWS (project 03) | On Kubernetes (project 05) |
| --- | --- | --- |
| Recreate the idle container with a new `APP_VERSION` | New launch template on the idle Auto Scaling Group, scale it up | New image on the idle Deployment |
| `curl /health` before the switch | Wait until the idle target group is healthy | Wait until the idle pods are Ready |
| Rewrite the Nginx upstream and reload | Change listener weights | Change the Service selector |
| `rollback.sh` | Set `active_color` back, while the old group still has instances | Patch the selector back |

Terraform can express the weights. It should not be the thing that polls `/health` and then flips. This script is that controller. In a company it would be a pipeline stage with the same three steps.

## Concepts this makes easy to discuss

- **Blue-green.** Two full environments. Traffic moves in one step. Rollback is a pointer change, not a redeploy, as long as the old environment is still running.
- **Rolling.** Replace instances inside one environment. You use less capacity, and you cannot return to the exact previous set in one action.
- **Canary.** A small share of traffic goes to the new version first. The Terraform module does this with `canary_weight`. This Docker lab stays at 0 or 100 so the cutover is obvious in `/version`.
- **Backward-compatible changes.** Both versions are alive during the switch. A database migration has to work for both. Add the new column, deploy, then remove the old one.
- **Connection draining.** Nginx reload keeps existing workers until their requests finish. The AWS side of that is the target group deregistration delay.
- **Why the old color stays up.** Rollback time is the time to reload a config. If you delete the old color immediately, rollback means deploying it again.

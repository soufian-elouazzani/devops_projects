# Application

A single Python process with no third-party libraries. Every other project in the repository deploys this same service, so the portfolio is one system rather than a pile of unrelated tutorials.

## Contract

| Path | Purpose |
| --- | --- |
| `GET /health` | Load balancer, Kubernetes, and the blue-green script decide whether this process may receive traffic |
| `GET /version` | Returns `color` and `version`, which is how you prove a cutover actually happened |
| `GET /metrics` | Prometheus text format for the observability stack |
| `GET /` | Plain HTML page showing the same identity |

`DEPLOY_COLOR` and `APP_VERSION` come from the environment. The deployment tooling owns those values. The application does not.

## Run

```bash
DEPLOY_COLOR=blue APP_VERSION=1.0.0 python3 app.py
python3 -m unittest test_app -v
docker build -t platform-lab:local .
```

## Why this image is a single stage

A multi-stage build earns its place when the build needs a compiler, package manager, or toolchain that must not ship in the runtime image. This service is one file and the standard library. The image still follows the practices that matter here: a pinned base, a non-root user, an explicit port, and a container healthcheck that calls the same `/health` endpoint the load balancer uses.

# Observability

Prometheus scrapes `/metrics` from the application. Two alert rules describe "the process disappeared" and "the request rate is above a lab threshold". Grafana loads one dashboard from files, so there is nothing to click together after startup.

The Grafana admin password in the compose file is `admin`. That is a local lab default. Do not reuse it anywhere else, and do not expose port 3000 on a public host.

```bash
docker compose up -d --build
```

| URL | What it is |
| --- | --- |
| http://127.0.0.1:8090/version | The application, direct |
| http://127.0.0.1:9090 | Prometheus. Open `Alerts` and the query `app_requests_total` |
| http://127.0.0.1:3000 | Grafana, folder `platform-lab`, dashboard `platform-lab` |

Generate traffic so the rate panel moves:

```bash
for i in $(seq 1 20); do curl -s -o /dev/null http://127.0.0.1:8090/; done
```

Stop it with `docker compose down`.

## What is alertable here

`AppTargetDown` fires when the scrape fails for 30 seconds. That is the same fact as a load balancer health check, stored over time. `AppRequestRateHigh` is a threshold on `rate()`, which needs more than one sample. A single curl will not page anyone, and it should not.

Project 01 prints a one-shot view of the host. This project keeps the series. Neither one pages a human by itself: wiring Alertmanager, a silence, and an on-call rotation is the production step that this lab leaves out on purpose.

## Concepts this makes easy to discuss

- **RED and USE.** Rate, errors, duration for a service. Utilization, saturation, errors for a resource. This app exposes rate. It does not expose duration yet. Saying that out loud is better than pretending a counter is a full SLO.
- **`for` on an alert.** A single missed scrape should not page. The `for` duration is the patience.
- **Labels.** `color` and `version` are labels so a blue-green cutover is visible as a second series instead of a reset you cannot explain.
- **Cardinality.** Those two labels are bounded. Putting a user id or a raw URL on a metric is how a Prometheus server falls over.
- **Dashboards as code.** The JSON is provisioned. A dashboard that exists only in a click-path disappears with the container.

# Host health snapshot

A read-only Linux report you can run over SSH before you have Prometheus on a machine. It prints capacity, who is logged in, failed login lines it can read, and the processes using CPU and memory. With `--json` the same facts are one object, so a later collector can scrape a host that does not yet run an exporter.

```bash
chmod +x server-stats.sh
./server-stats.sh
./server-stats.sh --json
./server-stats.sh --mem 50 --disk 70
```

The process exits `0` when CPU, memory, and the fullest real filesystem are under the thresholds. It exits `1` when any threshold is crossed. Defaults are 80% CPU, 80% memory, and 85% disk.

Reading `/var/log/auth.log` or `/var/log/secure` needs permission to those files. Without it, the failed-login count is `0` and the rest of the report still runs.

## Concepts this makes easy to discuss

- **USE method.** Utilization, saturation, and errors. CPU and memory percentages are utilization. Load average is a saturation hint. Failed logins are an error signal, not a performance one.
- **Why a script is not a monitoring system.** It is a point-in-time view. It does not store history, so it cannot answer "when did this start?". Project 06 keeps the time series.
- **Exit codes as a contract.** A human reads the text. A check in CI or a cron wrapper only needs the status.
- **Auth logs are sensitive.** The script counts and does not ship raw log lines in JSON mode. A production collector would send them to a logging pipeline with retention and access control, not into a metrics system.

This started from the [server stats](https://roadmap.sh/projects/server-stats) exercise and now feeds the same operational questions as the Prometheus alerts later in the repo.

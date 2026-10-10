# Configuration management

Ansible configures a Debian or Ubuntu host into the same shape every time: a baseline package set, the platform-lab process under systemd, and nginx in front of it. The playbook is the server equivalent of the container and the Terraform user-data. All three start the same `app.py` contract.

```bash
ansible-playbook --syntax-check site.yml
ansible-playbook site.yml --check --diff
ansible-playbook site.yml
ansible-playbook site.yml --tags nginx
```

Point `inventory/hosts.yml` at a real host first. The sample address `10.20.1.10` is a placeholder. The SSH authorized-key task does nothing until `ssh_public_key` in `group_vars/web.yml` no longer contains `REPLACE_WITH`.

## What is idempotent here

Running the playbook twice is the test. Packages stay present, the unit stays enabled, and nginx reloads only when the template changed. Handlers are what make that reload happen: a task notifies, Ansible runs the handler once at the end.

Color and version live in `group_vars/web.yml`, not in the unit file. Changing `app_version` and applying again is a host-level release. It is not blue-green. Project 04 is the release strategy; this project is how a single host is made and kept correct.

## Concepts this makes easy to discuss

- **Idempotence.** Describe the state you want. Do not write a script that appends a line every time it runs.
- **Roles.** `common`, `app`, and `nginx` can be applied separately with tags and reused by another play.
- **Handlers.** Restart the process when the binary or the environment file changes, not on every run.
- **Inventory versus variables.** The host list and the desired version are different facts and live in different files.
- **Push, not pull.** Ansible connects out to the host. GitOps in project 07 pulls. Both are valid; they fail differently when the network is partitioned.

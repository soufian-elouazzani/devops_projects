# GitOps

Argo CD watches this repository and applies `projects/05-kubernetes` to the cluster. The desired state is the Git commit. A manual `kubectl patch` is drift, and the next sync puts the Service selector back to whatever `service.yaml` says.

This file does not install Argo CD. It is the application object you would add once Argo CD is running in the `argocd` namespace. Sync is manual: open the application and sync it, or run `argocd app sync platform-lab`. Automated sync is a one-line change after you are sure the traffic switch itself is a commit.

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

`selfHeal` reverts out-of-band patches. `prune` deletes objects you removed from Git. Turn prune on only when you trust that Git is complete.

## Push and pull

| | GitHub Actions (this repo's CI) | Argo CD |
| --- | --- | --- |
| Direction | The pipeline pushes a build, a validation, or a deploy | The cluster pulls the manifests |
| Credentials | The runner needs permission to reach the destination | The cluster needs permission to read Git |
| Drift | Invisible until something checks the live objects | Visible, and optional self-heal |
| Blue-green | A job can run `deploy.sh` or `kubectl apply` | The cutover is the commit that changes the Service selector |

CI in `.github/workflows` is the push side: tests, Terraform validation, Ansible syntax, Kubernetes dry-run, and the image build. It does not SSH into a cluster. Delivery of the manifests is this pull side.

## Concepts this makes easy to discuss

- **The source of truth.** If both a person and a controller can change the cluster, you need to know which one wins. Here, Git wins after a sync.
- **Why the blue-green switch moves into Git.** Otherwise auto-sync fights the script and sends traffic back to the old color.
- **Pull is easier to audit.** The deploy is a commit. The cluster does not need a long-lived credential stored in GitHub.
- **This lab does not pretend Argo CD is installed.** The manifest is the interface. Installing the controller is a separate system.

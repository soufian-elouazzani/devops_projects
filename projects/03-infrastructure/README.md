# Infrastructure as code

Terraform builds the AWS shape of the same service the Docker demo runs locally: a VPC, an internet-facing load balancer, and two independent groups of instances. Blue and green each have a target group. The listener forwards by weight.

Applying this creates billable resources. An Application Load Balancer and a NAT Gateway are charged while they exist, including when no one is sending traffic. Run `terraform destroy` when you are finished with a real account. `terraform validate` does not create anything.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

`terraform.tfvars` is gitignored. The example file is the contract.

## How a release works

Do not flip the color and scale the new group in the same apply. Terraform updates both resources, but it does not wait until the new instances pass `/health` before it moves the listener.

1. Set `warm_standby = true` and set `app_version_green` to the new version. Apply. Wait until the green target group is healthy.
2. Set `active_color = "green"`. Apply. The listener weight moves to green.
3. Set `warm_standby = false`. Apply. Blue scales to zero and stays as the next empty slot.

Rollback is step 2 in reverse, which is only fast if the previous color is still warm. `canary_weight = 10` sends 10 percent of traffic to the inactive color instead of cutting over. That is the same module, used as a canary.

Project 04 is this procedure with the health gate automated, on your laptop, with no AWS bill.

## What the modules are responsible for

| Module | Owns |
| --- | --- |
| `network` | VPC, two public subnets, two private subnets, one NAT Gateway |
| `security` | Load balancer open on port 80, instances open on 8080 only from the load balancer |
| `alb` | Two target groups and a weighted forward action |
| `compute` | Launch templates, Auto Scaling Groups, SSM instance role, IMDSv2 |

Instances have no SSH ingress. Administration is AWS Systems Manager Session Manager, via `AmazonSSMManagedInstanceCore`. Metadata uses IMDSv2 (`http_tokens = required`), so a process on the box cannot steal role credentials with a simple request to the metadata IP.

User-data installs `app/app.py` and starts it with systemd. The color and version are baked into the launch template. In a longer pipeline the template would pull an image from a registry. The health contract would stay the same, which is why the load balancer checks `/health` and not a TCP port.

## State

The lab uses the local backend so `terraform validate` works with no account. `backend.tf.example` shows the production layout: S3 for the state file, encryption, and a DynamoDB lock table. The lock is what makes two applies queue instead of corrupting state.

## Concepts this makes easy to discuss

- **Why private subnets.** The instances are not on the internet. Only the load balancer is. The NAT Gateway is the outbound path for package installs and SSM.
- **Target group health checks versus Terraform.** The health check is the source of truth for "this instance can take traffic". An apply finishing is not.
- **Blue-green versus rolling.** `instance_refresh` on one group is a rolling replace. Two groups plus a weight change is blue-green. Rolling cannot give you the old full stack back in one switch.
- **Expand and contract for data.** Both versions run during the cutover. A schema change has to work for the old code and the new code at the same time. Add a column first, deploy the code, remove the old column later.
- **Cost of idle infrastructure.** Desired capacity `0` on the inactive color is how this lab avoids paying for a full second fleet. The tradeoff is a slower cutover, which `warm_standby` buys back.

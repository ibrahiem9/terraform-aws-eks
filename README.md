# Minimal AWS EKS Terraform Module

This fork strips the original `terraform-aws-modules/terraform-aws-eks` project down to the essentials. It deploys an EKS control plane, a shared security perimeter, managed node groups, the core EKS add-ons, optional access entries, and secrets encryption with the AWS managed KMS key.

## Features
- EKS cluster with private and/or public endpoints, CloudWatch logging, and secrets encryption (defaults to the AWS managed `alias/aws/eks` key)
- Managed node groups with sensible defaults (per-node security group, IAM role, scaling configuration) and optional overrides per node group
- Default add-ons for `coredns`, `kube-proxy`, `vpc-cni`, and `aws-ebs-csi-driver`, with the option to extend or tune each add-on
- OIDC provider for IRSA plus a simplified map-based interface for EKS access entries
- Minimal IAM footprint: one cluster role and one node role unless you provide existing ARNs

## Quick Start
```hcl
module "eks" {
  source = "git::https://github.com/your-org/terraform-aws-eks.git"

  name               = "example"
  kubernetes_version = "1.30"

  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-aaaabbbb",
    "subnet-bbbbcccc",
    "subnet-ccccdddd",
  ]

  managed_node_groups = {
    general = {
      desired_size = 2
      min_size     = 2
      max_size     = 4
      instance_types = ["t3.large"]
      labels = {
        workload = "general"
      }
    }
  }

  access_entries = {
    platform = {
      principal_arn = "arn:aws:iam::123456789012:role/platform-admin"
      access_policy = {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
    }
  }

  tags = {
    Environment = "development"
    Project     = "minimal-eks"
  }
}
```

## Node Groups
Each entry in `managed_node_groups` can override the defaults below. Only provide the keys you need.

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `name` | string | map key | Node group name |
| `desired_size` | number | `2` | Desired node count |
| `min_size` | number | `1` | Minimum node count |
| `max_size` | number | `3` | Maximum node count |
| `instance_types` | list(string) | `["t3.medium"]` | EC2 instance types to use |
| `capacity_type` | string | `"ON_DEMAND"` | `"ON_DEMAND"` or `"SPOT"` |
| `disk_size` | number | provider default | Root volume size (GiB) |
| `ami_type` | string | provider default | Optional AMI type override |
| `subnets` | list(string) | module `subnet_ids` | Subnets dedicated to the node group |
| `labels` | map(string) | `{}` | Kubernetes labels |
| `taints` | list(object) | `[]` | `{ key, value, effect }` taints |
| `tags` | map(string) | `{}` | Extra AWS tags for the node group |

## Add-ons
The module enables the four core add-ons by default. You can supply a different map to adjust versions or add new add-ons:

```hcl
addons = {
  coredns = {}
  vpc-cni = {
    configuration_values = jsonencode({
      env = {
        WARM_IP_TARGET = "1"
      }
    })
  }
  "aws-ebs-csi-driver" = {
    addon_version = "v1.30.0-eksbuild.1"
  }
  "eks-pod-identity-agent" = {}
}
```

## Key Inputs
- `name` – EKS cluster name (required)
- `vpc_id` / `subnet_ids` – networking configuration for the control plane and nodes (required)
- `managed_node_groups` – map describing the managed node groups (optional but recommended)
- `addons` – map of cluster add-ons (defaults to the four core add-ons)
- `access_entries` – optional map of access entries
- `enable_encryption` / `encryption_key_arn` – toggle or supply a custom KMS key
- `cluster_role_arn` / `node_role_arn` – provide existing IAM roles if you do not want the module to create them

See `variables.tf` and `outputs.tf` for the authoritative list of inputs and outputs.

## Outputs
- Cluster metadata: `cluster_name`, `cluster_arn`, `cluster_endpoint`, `cluster_version`, `cluster_certificate_authority_data`
- IAM: `cluster_role_arn`, `node_role_arn`, `oidc_provider_arn`
- Networking: `cluster_security_group_id`, `node_security_group_id`
- Workloads: `managed_node_groups`, `cluster_addons`
- Access management: `access_entries`
- Observability: `cloudwatch_log_group_name`

## Development
Run `terraform fmt` after making changes. The repository no longer keeps auto-generated docs; the README and Terraform configurations are the source of truth.

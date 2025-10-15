output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint for the Kubernetes API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version for the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "ID of the shared node security group"
  value       = try(aws_security_group.node[0].id, null)
}

output "cluster_role_arn" {
  description = "IAM role ARN used by the EKS cluster"
  value       = local.cluster_role_arn
}

output "node_role_arn" {
  description = "IAM role ARN used by the managed node groups"
  value       = local.node_role_arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = try(aws_eks_cluster.this.identity[0].oidc[0].issuer, null)
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider created for IRSA"
  value       = try(aws_iam_openid_connect_provider.this[0].arn, null)
}

output "cluster_addons" {
  description = "Map of EKS add-ons created by this module"
  value       = aws_eks_addon.this
}

output "access_entries" {
  description = "Map of EKS access entries created by this module"
  value       = aws_eks_access_entry.this
}

output "managed_node_groups" {
  description = "Map of managed node groups created by this module"
  value       = aws_eks_node_group.this
}

output "cloudwatch_log_group_name" {
  description = "Name of the control plane CloudWatch Log Group"
  value       = try(aws_cloudwatch_log_group.cluster[0].name, null)
}

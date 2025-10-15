variable "name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes `<major>.<minor>` version to deploy (for example, `1.30`)"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID of the VPC where cluster and node security groups will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs used for the EKS control plane and managed node groups"
  type        = list(string)
}

variable "additional_cluster_security_group_ids" {
  description = "Additional security groups to attach to the cluster control plane"
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Enable the private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable the public API server endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_log_types" {
  description = "Cluster control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}

variable "cluster_tags" {
  description = "Additional tags to apply to the EKS cluster"
  type        = map(string)
  default     = {}
}

variable "cluster_security_group_name" {
  description = "Custom name for the cluster security group (defaults to `<cluster>-cluster`)"
  type        = string
  default     = null
}

variable "cluster_security_group_tags" {
  description = "Additional tags to apply to the cluster security group"
  type        = map(string)
  default     = {}
}

variable "node_security_group_name" {
  description = "Custom name for the shared node security group (defaults to `<cluster>-nodes`)"
  type        = string
  default     = null
}

variable "node_security_group_tags" {
  description = "Additional tags to apply to the node security group"
  type        = map(string)
  default     = {}
}

variable "create_cloudwatch_log_group" {
  description = "Create a CloudWatch Log Group for the control plane logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Retention in days for the control plane CloudWatch Log Group"
  type        = number
  default     = 90
}

variable "enable_encryption" {
  description = "Enable secrets encryption with AWS Key Management Service"
  type        = bool
  default     = true
}

variable "encryption_key_arn" {
  description = "Custom KMS key ARN for cluster secrets encryption. Defaults to the AWS managed `alias/aws/eks` key"
  type        = string
  default     = null
}

variable "enable_irsa" {
  description = "Create an IAM OIDC provider for IRSA integration"
  type        = bool
  default     = true
}

variable "irsa_additional_audiences" {
  description = "Additional audiences to include in the IRSA provider"
  type        = list(string)
  default     = []
}

variable "cluster_role_arn" {
  description = "Existing IAM role ARN for the EKS cluster. If unset, a role is created"
  type        = string
  default     = null
}

variable "cluster_role_name" {
  description = "Name for the EKS cluster IAM role when one is created"
  type        = string
  default     = null
}

variable "node_role_arn" {
  description = "Existing IAM role ARN for managed node groups. If unset, a role is created when node groups are defined"
  type        = string
  default     = null
}

variable "node_role_name" {
  description = "Name for the managed node group IAM role when one is created"
  type        = string
  default     = null
}

variable "addons" {
  description = "Map of EKS add-on configurations to enable"
  type = map(object({
    name                 = optional(string)
    addon_version        = optional(string)
    most_recent          = optional(bool, true)
    configuration_values = optional(string)
    service_account_role_arn = optional(string)
    tags                 = optional(map(string), {})
  }))
  default = {
    coredns              = {}
    kube-proxy           = {}
    vpc-cni              = {}
    "aws-ebs-csi-driver" = {}
  }
}

variable "managed_node_groups" {
  description = "Map of managed node group configurations to create"
  type = map(object({
    name          = optional(string)
    desired_size  = optional(number)
    min_size      = optional(number)
    max_size      = optional(number)
    instance_types = optional(list(string))
    capacity_type = optional(string)
    disk_size     = optional(number)
    ami_type      = optional(string)
    subnets       = optional(list(string))
    labels        = optional(map(string))
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
    tags = optional(map(string))
  }))
  default = {}
}

variable "access_entries" {
  description = "Map of EKS access entries to create"
  type = map(object({
    principal_arn     = string
    type              = optional(string)
    kubernetes_groups = optional(list(string), [])
    tags              = optional(map(string), {})
    access_policy = optional(object({
      policy_arn               = string
      access_scope_type        = optional(string, "cluster")
      access_scope_namespaces  = optional(list(string))
    }))
  }))
  default = {}
}

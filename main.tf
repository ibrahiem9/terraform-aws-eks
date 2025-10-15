data "aws_partition" "current" {}

data "aws_kms_key" "default" {
  count = var.enable_encryption && var.encryption_key_arn == null ? 1 : 0

  key_id = "alias/aws/eks"
}

locals {
  cluster_role_name           = coalesce(var.cluster_role_name, "${var.name}-cluster")
  node_role_name              = coalesce(var.node_role_name, "${var.name}-nodes")
  cluster_security_group_name = coalesce(var.cluster_security_group_name, "${var.name}-cluster")
  node_security_group_name    = coalesce(var.node_security_group_name, "${var.name}-nodes")

  cluster_role_arn = var.cluster_role_arn != null ? var.cluster_role_arn : try(aws_iam_role.cluster[0].arn, null)
  node_role_arn    = var.node_role_arn != null ? var.node_role_arn : try(aws_iam_role.node[0].arn, null)

  addons        = var.addons != null ? var.addons : {}
  access_entries = var.access_entries != null ? var.access_entries : {}
}

################################################################################
# IAM Roles
################################################################################

data "aws_iam_policy_document" "cluster_assume_role" {
  count = var.cluster_role_arn == null ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  count = var.cluster_role_arn == null ? 1 : 0

  name        = var.cluster_role_name != null ? var.cluster_role_name : null
  name_prefix = var.cluster_role_name == null ? "${local.cluster_role_name}-" : null
  description = "EKS cluster role for ${var.name}"

  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role[0].json

  tags = merge(var.tags, { Name = local.cluster_role_name })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = var.cluster_role_arn == null ? {
    AmazonEKSClusterPolicy        = "AmazonEKSClusterPolicy"
    AmazonEKSVPCResourceController = "AmazonEKSVPCResourceController"
  } : {}

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
  role       = aws_iam_role.cluster[0].name
}

data "aws_iam_policy_document" "node_assume_role" {
  count = var.node_role_arn == null && length(local.managed_node_groups) > 0 ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  count = var.node_role_arn == null && length(local.managed_node_groups) > 0 ? 1 : 0

  name        = var.node_role_name != null ? var.node_role_name : null
  name_prefix = var.node_role_name == null ? "${local.node_role_name}-" : null
  description = "EKS managed node group role for ${var.name}"

  assume_role_policy = data.aws_iam_policy_document.node_assume_role[0].json

  tags = merge(var.tags, { Name = local.node_role_name })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = var.node_role_arn == null && length(local.managed_node_groups) > 0 ? {
    AmazonEKSWorkerNodePolicy         = "AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy              = "AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "AmazonEC2ContainerRegistryReadOnly"
  } : {}

  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
  role       = aws_iam_role.node[0].name
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "cluster" {
  name_prefix = "${local.cluster_security_group_name}-"
  description = "EKS cluster security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    var.cluster_security_group_tags,
    { Name = local.cluster_security_group_name },
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "node" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  name_prefix = "${local.node_security_group_name}-"
  description = "Shared security group for EKS managed node groups in ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    var.node_security_group_tags,
    {
      Name                              = local.node_security_group_name
      "kubernetes.io/cluster/${var.name}" = "owned"
    },
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster_ingress_api" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Allow managed nodes to communicate with the cluster API server"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node[0].id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  description       = "Allow cluster egress to the VPC"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node_ingress_api" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Allow cluster API to reach managed nodes"
  security_group_id        = aws_security_group.node[0].id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "node_ingress_kubelet" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  description              = "Allow cluster API to reach node kubelets"
  security_group_id        = aws_security_group.node[0].id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "node_ingress_dns_tcp" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  type        = "ingress"
  from_port   = 53
  to_port     = 53
  protocol    = "tcp"
  description = "Allow node-to-node DNS over TCP"
  security_group_id = aws_security_group.node[0].id
  self              = true
}

resource "aws_security_group_rule" "node_ingress_dns_udp" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  type        = "ingress"
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  description = "Allow node-to-node DNS over UDP"
  security_group_id = aws_security_group.node[0].id
  self              = true
}

resource "aws_security_group_rule" "node_egress_all" {
  count = length(local.managed_node_groups) > 0 ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  description       = "Allow nodes to reach the internet"
  security_group_id = aws_security_group.node[0].id
  cidr_blocks       = ["0.0.0.0/0"]
}

################################################################################
# CloudWatch Logs
################################################################################

resource "aws_cloudwatch_log_group" "cluster" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = merge(
    var.tags,
    { Name = "/aws/eks/${var.name}/cluster" },
  )
}

################################################################################
# EKS Cluster
################################################################################

resource "aws_eks_cluster" "this" {
  name    = var.name
  role_arn = local.cluster_role_arn
  version = var.kubernetes_version

  enabled_cluster_log_types = var.enabled_log_types

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = compact(concat([aws_security_group.cluster.id], var.additional_cluster_security_group_ids))
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  dynamic "encryption_config" {
    for_each = var.enable_encryption ? [1] : []

    content {
      provider {
        key_arn = var.encryption_key_arn != null ? var.encryption_key_arn : data.aws_kms_key.default[0].arn
      }
      resources = ["secrets"]
    }
  }

  tags = merge(
    var.tags,
    var.cluster_tags,
  )
}

################################################################################
# IRSA (OIDC Provider)
################################################################################

data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0

  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = distinct(concat(["sts.amazonaws.com"], var.irsa_additional_audiences))
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    { Name = "${var.name}-eks-irsa" },
  )
}

################################################################################
# Access Entries
################################################################################

resource "aws_eks_access_entry" "this" {
  for_each = local.access_entries

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  type              = try(each.value.type, null)
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  tags              = merge(var.tags, try(each.value.tags, {}))
}

resource "aws_eks_access_policy_association" "this" {
  for_each = {
    for key, value in local.access_entries :
    key => value if try(value.access_policy.policy_arn, "") != ""
  }

  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = each.value.access_policy.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    type       = try(each.value.access_policy.access_scope_type, "cluster")
    namespaces = try(each.value.access_policy.access_scope_namespaces, null)
  }

  depends_on = [
    aws_eks_access_entry.this,
  ]
}

################################################################################
# Add-ons
################################################################################

data "aws_eks_addon_version" "this" {
  for_each = local.addons

  addon_name         = coalesce(try(each.value.name, null), each.key)
  kubernetes_version = coalesce(var.kubernetes_version, aws_eks_cluster.this.version)
  most_recent        = try(each.value.most_recent, true)
}

resource "aws_eks_addon" "this" {
  for_each = local.addons

  cluster_name = aws_eks_cluster.this.name
  addon_name   = coalesce(try(each.value.name, null), each.key)

  addon_version        = coalesce(try(each.value.addon_version, null), data.aws_eks_addon_version.this[each.key].version)
  configuration_values = try(each.value.configuration_values, null)
  service_account_role_arn = try(each.value.service_account_role_arn, null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
  )
}

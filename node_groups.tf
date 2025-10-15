locals {
  managed_node_group_defaults = {
    name          = null
    desired_size  = 2
    min_size      = 1
    max_size      = 3
    instance_types = []
    capacity_type = "ON_DEMAND"
    disk_size     = null
    ami_type      = null
    subnets       = null
    labels        = {}
    taints        = []
    tags          = {}
  }

  managed_node_groups = {
    for key, value in var.managed_node_groups :
    key => merge(
      local.managed_node_group_defaults,
      value,
      { name = coalesce(try(value.name, null), key) },
    )
  }
}

resource "aws_eks_node_group" "this" {
  for_each = local.managed_node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.value.name
  node_role_arn   = local.node_role_arn
  subnet_ids      = length(compact(coalesce(each.value.subnets, []))) > 0 ? each.value.subnets : var.subnet_ids

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  capacity_type = each.value.capacity_type
  disk_size     = each.value.disk_size
  ami_type      = each.value.ami_type
  instance_types = length(each.value.instance_types) > 0 ? each.value.instance_types : ["t3.medium"]
  labels         = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
  )

  depends_on = [
    aws_security_group_rule.node_ingress_api,
  ]
}

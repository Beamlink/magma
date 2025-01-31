################################################################################
# Copyright 2020 The Magma Authors.

# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

locals {
  # orc8r_worker_group = var.enable_orc8r_blue_green_deployment ? var.blue_green_worker_groups : var.eks_worker_groups
  orc8r_worker_group = var.eks_worker_groups
}

resource "tls_private_key" "eks_workers" {
  count = var.eks_worker_group_key == null ? 1 : 0

  algorithm = "RSA"
}

resource "aws_key_pair" "eks_workers" {
  count = var.eks_worker_group_key == null ? 1 : 0

  key_name_prefix = var.cluster_name
  public_key      = tls_private_key.eks_workers[0].public_key_openssh
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.30.2"
  # version = ">= 19.16.0"
  prefix_separator = ""
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = length(module.vpc.private_subnets) > 0 ? module.vpc.private_subnets : module.vpc.public_subnets

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  cluster_additional_security_group_ids = concat([aws_security_group.default.id], var.eks_worker_additional_sg_ids)
  iam_role_additional_policies          = var.eks_worker_additional_policy_arns
  eks_managed_node_groups               = var.thanos_enabled ? concat(local.orc8r_worker_group, var.thanos_worker_groups) : local.orc8r_worker_group

  eks_managed_node_group_defaults = {
    iam_role_attach_cni_policy = true
  }

  aws_auth_roles = var.eks_map_roles
  aws_auth_users = var.eks_map_users

  tags = var.global_tags

  enable_irsa = var.eks_enable_irsa
}

# role assume policy for eks workers
data "aws_iam_policy_document" "eks_worker_assumable" {
  statement {
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }

  statement {
    principals {
      identifiers = [module.eks.cluster_iam_role_arn]
      type        = "AWS"
    }
    actions = ["sts:AssumeRole"]
  }
}

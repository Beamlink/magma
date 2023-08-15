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



##############################################################################
# Terraform Provider Configuration
##############################################################################
# terraform {
#   required_providers {
#     aws = {
#       version = "~> 4.67"
#     }
#   }
# }
terraform {
  backend "s3" {
    bucket = "magma-terraform-s3"
    key    = "magma-orc8r.tfstate"
    dynamodb_table = "magma-terraform-lock"
    region = "us-east-2"
  }
}

locals {
  region        = "us-east-2"
  magma_version = "v1.8"
}

# Don't think this is being picked up...
provider "aws" {
  default_tags {
    tags = {
      magma_flavor  = "vanilla"
      magma_version = local.magma_version
    }
  }
}


##############################################################################
# Secret Values Retrieval
#
##############################################################################
# This secretsmanager secret needs to be manually created and populated in the
# AWS console. Included key-values pairs:
#   orc8r_db_pass
#   docker_registry
#   docker_user
#   docker_pass
#   helm_repo
#   helm_user
#   helm_pass
data "aws_secretsmanager_secret" "magma_orc8r_tf_secrets" {
  name = "magma_orc8r_tf_secrets"
}

data "aws_secretsmanager_secret_version" "magma_orc8r_tf_secrets" {
  secret_id = data.aws_secretsmanager_secret.magma_orc8r_tf_secrets.id
}


##############################################################################
# Orchestrator "Infrastructure" Configuration
#
# The child module is named "orc8r-aws"
# This module deploys the AWS infrastructure itself (Networking, database, k8s, etc.)
# The actual orc8r software is *not* deployed by this module.
##############################################################################

module "orc8r" {
  # Change this to pull from GitHub with a specified ref, e.g.
  # source = "github.com/magma/magma//orc8r/cloud/deploy/terraform/orc8r-aws?ref=v1.8"
  source = "../orc8r/cloud/deploy/terraform/orc8r-aws"

  region = local.region

  eks_worker_groups = {
    orc8r_worker_group = {
      name                = "wg-1"
      instance_types      = ["t3.small"]
      desired_size        = 2
      min_size            = 2
      max_size            = 2
      autoscaling_enabled = false
      kubelet_extra_args  = "" // object types must be identical (see thanos_worker_groups)
    }
  }

  orc8r_db_engine_version = "15.3"
  orc8r_db_password = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["orc8r_db_password"]
  orc8r_db_instance_class = "db.t3.micro"

  # setup_cert_manager = false
  secretsmanager_orc8r_secret = "orc8r-secret-store"
  orc8r_domain_name           = "orc8r.blmagma.com"

  orc8r_sns_email             = "quint.underwood@beamlink.io"
  enable_aws_db_notifications = true

  vpc_name        = "orc8r"
  cluster_name    = "orc8r"
  cluster_version = "1.27"

  deploy_elasticsearch = true
  # deploy_elasticsearch_service_linked_role = false
  elasticsearch_domain_name     = "orc8r-es"
  elasticsearch_version         = "7.10"
  elasticsearch_instance_type   = "t3.small.elasticsearch"
  elasticsearch_instance_count  = 2
  elasticsearch_az_count        = 2
  elasticsearch_ebs_enabled     = true
  elasticsearch_ebs_volume_size = 10
  elasticsearch_ebs_volume_type = "gp2"
}


##############################################################################
# Orchestrator "App" Configuration
#
# The child module is named "orc8r-helm-aws"
# This module deploys several helm charts to install the orc8r software
# onto the K8s cluster created above.
##############################################################################
module "orc8r-app" {
  # Change this to pull from GitHub with a specified ref, e.g.
  # source = "github.com/magma/magma//orc8r/cloud/deploy/terraform/orc8r-helm-aws?ref=v1.8"
  source = "../orc8r/cloud/deploy/terraform/orc8r-helm-aws"

  region = local.region

  # This has to match the backend block declared at the top. Unfortunately we
  # have to duplicate this because Terraform evaluates backend blocks before
  # the rest of the module.
  state_backend = "s3"
  state_config = {
    bucket         = "magma-terraform-s3"
    key            = "magma-orc8r.tfstate"
    dynamodb_table = "magma-terraform-lock"
    region         = "us-east-2"
  }

  cluster_name            = module.orc8r.cluster_name
  vpc_id                  = module.orc8r.vpc_id
  subnets                 = module.orc8r.subnets
  node_security_group_id  = module.orc8r.node_security_group_id
  oidc_provider_arn       = module.orc8r.oidc_provider_arn
  cluster_oidc_issuer_url = module.orc8r.cluster_oidc_issuer_url

  orc8r_domain_name     = module.orc8r.orc8r_domain_name
  orc8r_route53_zone_id = module.orc8r.route53_zone_id
  external_dns_role_arn = module.orc8r.external_dns_role_arn

  secretsmanager_orc8r_name = module.orc8r.secretsmanager_secret_name
  seed_certs_dir            = "~/secrets/certs"

  deploy_cert_manager_helm_chart    = module.orc8r.setup_cert_manager
  managed_certs_create              = module.orc8r.setup_cert_manager
  managed_certs_enabled             = module.orc8r.setup_cert_manager
  nms_managed_certs_enabled         = module.orc8r.setup_cert_manager
  cert_manager_route53_iam_role_arn = module.orc8r.cert_manager_route53_iam_role_arn

  orc8r_db_host    = module.orc8r.orc8r_db_host
  orc8r_db_port    = module.orc8r.orc8r_db_port
  orc8r_db_dialect = module.orc8r.orc8r_db_dialect
  orc8r_db_name    = module.orc8r.orc8r_db_name
  orc8r_db_user    = module.orc8r.orc8r_db_user
  orc8r_db_pass    = module.orc8r.orc8r_db_pass

  docker_registry = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["docker_registry"]
  docker_user = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["docker_username"]
  docker_pass = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["docker_password"]

  helm_repo = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["helm_repo"]
  helm_user = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["helm_username"]
  helm_pass = jsondecode(data.aws_secretsmanager_secret_version.magma_orc8r_tf_secrets.secret_string)["helm_password"]
  eks_cluster_id = module.orc8r.eks_cluster_id

  # efs_file_system_id       = module.orc8r.efs_file_system_id
  # efs_provisioner_role_arn = module.orc8r.efs_provisioner_role_arn

  elasticsearch_endpoint       = module.orc8r.es_endpoint
  elasticsearch_disk_threshold = tonumber(module.orc8r.es_volume_size * 75 / 100)

  orc8r_deployment_type = "fwa"
  # orc8r_tag             = "1.8.0"
  orc8r_tag = local.magma_version
}

output "nameservers" {
  value = module.orc8r.route53_nameservers
}

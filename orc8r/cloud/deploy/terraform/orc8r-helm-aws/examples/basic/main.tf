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
  region = "ap-south-1"
}

module "orc8r" {
  # Change this to pull from GitHub with a specified ref, e.g.
  # source = "github.com/magma/magma//orc8r/cloud/deploy/terraform/orc8r-aws?ref=v1.6"
  source = "../../../orc8r-aws"

  region = local.region

  # If you performing a fresh Orc8r install, choose a recent Postgres version
  # orc8r_db_engine_version     = "12.6"
  orc8r_db_password = "password" # must be at least 8 characters

  setup_cert_manager = false

  secretsmanager_orc8r_secret = "orc8r-secrets"
  orc8r_domain_name           = "orc8r.magmacore.link"

  orc8r_sns_email             = "admin@magmacore.link"
  enable_aws_db_notifications = true

  vpc_name     = "orc8r"
  cluster_name = "orc8r"

  deploy_elasticsearch = true

  deploy_elasticsearch_service_linked_role = false
}

module "orc8r-app" {
  # Change this to pull from GitHub with a specified ref, e.g.
  # source = "github.com/magma/magma//orc8r/cloud/deploy/terraform/orc8r-helm-aws?ref=v1.8"
  source = "../.."

  region = local.region

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

  # Note that this can be any container registry provider
  docker_registry = "docker.artifactory.magmacore.org"
  docker_user     = ""
  docker_pass     = ""

  # Note that this can be any Helm chart repo provider
  helm_repo      = "https://artifactory.magmacore.org/artifactory/helm"
  helm_user      = ""
  helm_pass      = ""
  eks_cluster_id = module.orc8r.eks_cluster_id

  # efs_file_system_id       = module.orc8r.efs_file_system_id
  # efs_csi_driver_arn       = module.orc8r.efs_csi_driver_arn

  elasticsearch_endpoint       = module.orc8r.es_endpoint
  elasticsearch_disk_threshold = tonumber(module.orc8r.es_volume_size * 75 / 100)

  orc8r_deployment_type = "fwa"
  orc8r_tag             = "1.8.0"
}

output "nameservers" {
  value = module.orc8r.route53_nameservers
}

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

output "orc8r_domain_name" {
  description = "Base domain name for Orchestrator application components."
  value       = var.orc8r_domain_name
}

output "eks_cluster_id" {
  description = "Cluster ID for the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "Cluster Name for the EKS cluster"
  value       = var.cluster_name
}

output "oidc_provider_arn" {
  description = "OIDC ARN"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnets" {
  value = length(module.vpc.private_subnets) > 0 ? module.vpc.private_subnets : module.vpc.public_subnets
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "eks_aws_auth_configmap_yaml" {
  description = "A K8s ConfigMap to allow authentication to the EKS cluster."
  value       = module.eks.aws_auth_configmap_yaml
  sensitive   = true
}

# output "efs_file_system_id" {
#   description = "ID of the EFS file system created for K8s persistent volumes."
#   value       = aws_efs_file_system.eks_pv.id
# }

# output "efs_csi_driver_arn" {
#   description = "ARN of the IAM role for the EFS CSI Driver."
#   value       = aws_iam_role.efs_csi_driver.arn
# }

output "es_endpoint" {
  description = "Endpoint of the ES cluster if deployed."
  value       = join("", aws_elasticsearch_domain.es.*.endpoint)
}

output "es_volume_size" {
  description = "Endpoint of the ES cluster if deployed."
  value       = var.elasticsearch_ebs_volume_size
}

output "secretsmanager_secret_name" {
  description = "Name of the Secrets Manager secret for deployment secrets"
  value       = aws_secretsmanager_secret.orc8r_secrets.name
}

output "orc8r_db_host" {
  description = "Hostname of the Orchestrator RDS instance"
  value       = aws_db_instance.default.address
}

output "orc8r_db_name" {
  description = "Database name for Orchestrator RDS instance"
  value       = aws_db_instance.default.db_name
}

output "orc8r_db_port" {
  description = "Database connection port for Orchestrator RDS instance"
  value       = aws_db_instance.default.port
}

output "orc8r_db_dialect" {
  description = "Database dialect for Orchestrator RDS instance"
  value       = var.orc8r_db_dialect
}

output "orc8r_db_user" {
  description = "Database username for Orchestrator RDS instance"
  value       = aws_db_instance.default.username
}

output "orc8r_db_pass" {
  description = "Orchestrator DB password"
  value       = aws_db_instance.default.password
  sensitive   = true
}

output "route53_zone_id" {
  description = "Route53 zone ID for Orchestrator domain name"
  value       = aws_route53_zone.orc8r.id
}

output "route53_nameservers" {
  description = "Route53 zone nameservers for external DNS configuration."
  value       = aws_route53_zone.orc8r.name_servers
}

output "external_dns_role_arn" {
  description = "IAM role ARN for external-dns"
  value       = aws_iam_role.external_dns.arn
}

output "setup_cert_manager" {
  description = "Create IAM role and policy for cert-manager."
  value       = var.setup_cert_manager
}

output "cert_manager_route53_iam_role_arn" {
  description = "IAM role ARN for cert-manager."
  value       = var.setup_cert_manager ? aws_iam_role.cert_manager_route53_iam_role.0.arn : null
}

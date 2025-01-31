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
  dockercfg_without_cred = {
    (var.docker_registry) = {

    }
  }
  dockercfg_with_cred = {
    (var.docker_registry) = {
      username = var.docker_user
      password = var.docker_pass
    }
  }
  dockercfg           = var.docker_user != "" ? local.dockercfg_with_cred : local.dockercfg_without_cred
  stable_helm_repo    = "https://charts.helm.sh/stable"
  # stable_helm_repo    = "https://artifactory.io"
  incubator_helm_repo = "https://charts.helm.sh/incubator"
}

resource "kubernetes_secret" "artifactory" {
  metadata {
    name      = "artifactory"
    namespace = kubernetes_namespace.orc8r.metadata[0].name
  }

  data = { ".dockercfg" = jsonencode(local.dockercfg) }
  type = "kubernetes.io/dockercfg"
}

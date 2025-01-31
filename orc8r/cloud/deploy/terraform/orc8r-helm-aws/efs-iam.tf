data "aws_iam_policy_document" "efs_csi_driver" {
  statement {
    actions = [
    # See this Github issue: https://github.com/kubernetes-sigs/aws-efs-csi-driver/issues/1056
    # This ec2 permission is not listed in the new set from Github issue above...including just in case
    "ec2:DescribeAvailabilityZones",
    "elasticfilesystem:DescribeMountTargets",
    "elasticfilesystem:DescribeAccessPoints",
    "elasticfilesystem:DescribeFileSystems",
    "elasticfilesystem:ClientMount",
    "elasticfilesystem:ClientWrite",
    "elasticfilesystem:CreateTags",
    "elasticfilesystem:CreateMountTarget",
    "elasticfilesystem:DeleteMountTarget",
    "elasticfilesystem:DeleteTags",
    "elasticfilesystem:TagResource",
    "elasticfilesystem:UntagResource"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "elasticfilesystem:CreateAccessPoint"
    ]
    resources = ["*"]
    effect    = "Allow"
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    actions = [
      "elasticfilesystem:DeleteAccessPoint"
    ]
    resources = ["*"]
    effect    = "Allow"
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "efs_csi_driver" {
  name        = "${var.cluster_name}-efs-csi-driver"
  # path        = "/"
  description = "Policy for the EFS CSI driver"

  policy = data.aws_iam_policy_document.efs_csi_driver.json
}

data "aws_iam_policy_document" "efs_csi_driver_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${var.efs_namespace}:${var.efs_service_account}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "efs_csi_driver" {
  name               = "${var.cluster_name}-efs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_driver_assume.json
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  role       = aws_iam_role.efs_csi_driver.name
  policy_arn = aws_iam_policy.efs_csi_driver.arn
}

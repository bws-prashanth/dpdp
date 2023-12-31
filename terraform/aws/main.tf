
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  #load_config_file       = false
}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name                 = "vpc-${var.name_suffix}"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/cluster-${var.name_suffix}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/cluster-${var.name_suffix}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
  tags = var.resource_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0"

  cluster_name    = "cluster-${var.name_suffix}"
  cluster_version = "1.21"
  #subnet_ids             = module.vpc.private_subnets
  subnets         = module.vpc.private_subnets
  cluster_endpoint_private_access = "true"
  cluster_endpoint_public_access = "true"
  tags = var.resource_tags
  vpc_id = module.vpc.vpc_id

  #eks_managed_node_groups
  node_groups = {
    first = {
      desired_capacity = 1
      max_capacity     = 10
      min_capacity     = 1
      instance_types = [var.ec2_eks_instance_type]
    }
  }
  cluster_create_timeout = "30m"
  cluster_delete_timeout = "30m"
  #cluster_timeouts = {
  #  create = "30m"
  #  update = "30m"
  #  delete = "30m"
  #}

  #write_kubeconfig      = true
  #config_output_path    = "/.kube/"
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = "cluster-${var.name_suffix}"
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}


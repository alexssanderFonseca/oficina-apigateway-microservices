terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Dados do Cluster EKS para configurar Helm e Kubernetes
data "aws_eks_cluster" "cluster" {
  name = "fase4-eks" # Ajuste conforme o nome real do seu cluster
}

data "aws_eks_cluster_auth" "cluster" {
  name = "fase4-eks"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# 1. Instalação do AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# 2. Aplicação do manifesto de Ingress que criamos no passo anterior
resource "kubernetes_manifest" "oficina_ingress" {
  manifest = yamldecode(file("${path.module}/../k8s/ingress.yaml"))
  
  depends_on = [helm_release.aws_load_balancer_controller]
}

# 3. Configuração do API Gateway (mantido do original)
locals {
  api_docs_final = file("${path.module}/../api-docs.json")
}

resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_name
  description = "API Gateway para a Oficina App (Centralizada)"
  body        = local.api_docs_final

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(local.api_docs_final)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.api_stage_name
}

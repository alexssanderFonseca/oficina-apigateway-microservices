#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# The name for the Helm release
HELM_RELEASE_NAME="ingress-nginx"
# The namespace for the installation
NAMESPACE="ingress-nginx"
# Default Cluster Name
CLUSTER_NAME=${1:-"EKS-FIAP"}
# AWS Region
REGION="us-east-1"

echo "🚀 Starting NGINX Ingress deployment for cluster: $CLUSTER_NAME (AWS Academy friendly)"

# --- Pre-flight Checks & Auto-Install ---

# Function to install Helm
install_helm() {
  echo "📦 Helm not found. Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

# Check for required tools
if ! command -v helm &> /dev/null; then
  install_helm
fi

for tool in kubectl aws; do
  if ! command -v $tool &> /dev/null; then
    echo "❌ Error: $tool is not installed. Please install it first."
    exit 1
  fi
done

# --- Deployment Steps ---

echo "1. Updating kubeconfig for EKS cluster..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

echo "2. Adding NGINX Ingress Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx > /dev/null
helm repo update > /dev/null

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE 2>/dev/null || true

# Install or Upgrade NGINX Ingress Controller
# Type LoadBalancer works in AWS Academy by creating a Classic Load Balancer
if helm status $HELM_RELEASE_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo "3. Upgrading NGINX Ingress Controller..."
  helm upgrade $HELM_RELEASE_NAME ingress-nginx/ingress-nginx \
    -n $NAMESPACE \
    --set controller.service.type=LoadBalancer \
    --set controller.ingressClassResource.default=true
else
  echo "3. Installing NGINX Ingress Controller..."
  helm install $HELM_RELEASE_NAME ingress-nginx/ingress-nginx \
    -n $NAMESPACE \
    --set controller.service.type=LoadBalancer \
    --set controller.ingressClassResource.default=true
fi

echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl rollout status deployment/$HELM_RELEASE_NAME-controller -n $NAMESPACE --timeout=150s

echo "4. Applying Ingress manifest for microservices routing..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGRESS_FILE="$SCRIPT_DIR/../k8s/ingress.yaml"

if [ -f "$INGRESS_FILE" ]; then
  kubectl apply -f "$INGRESS_FILE"
else
  echo "⚠️ Warning: Ingress file not found at $INGRESS_FILE. Skipping ingress application."
fi

echo "✅ Deployment completed successfully."
echo "   Run 'kubectl get svc -n $NAMESPACE' to get the LoadBalancer DNS."

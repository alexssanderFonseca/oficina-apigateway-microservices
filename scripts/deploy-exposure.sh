#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# The name for the Helm release
HELM_RELEASE_NAME="aws-load-balancer-controller"
# The namespace for the installation
NAMESPACE="kube-system"
# Default Cluster Name (can be overridden by the first argument)
CLUSTER_NAME=${1:-"EKS-FIAP"}
# AWS Region
REGION="us-east-1"

echo "🚀 Starting exposure infrastructure deployment for cluster: $CLUSTER_NAME"

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

echo "2. Adding AWS EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts > /dev/null
helm repo update > /dev/null

# Check if the release already exists to decide between install or upgrade
if helm status $HELM_RELEASE_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo "3. Upgrading AWS Load Balancer Controller..."
  helm upgrade $HELM_RELEASE_NAME eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName="$CLUSTER_NAME" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
else
  echo "3. Installing AWS Load Balancer Controller..."
  helm install $HELM_RELEASE_NAME eks/aws-load-balancer-controller \
    -n $NAMESPACE \
    --set clusterName="$CLUSTER_NAME" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
fi

echo "4. Applying Ingress manifest for microservices routing..."
# Assuming the script is run from the root of the repo or scripts/ directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGRESS_FILE="$SCRIPT_DIR/../k8s/ingress.yaml"

if [ -f "$INGRESS_FILE" ]; then
  kubectl apply -f "$INGRESS_FILE"
else
  echo "⚠️ Warning: Ingress file not found at $INGRESS_FILE. Skipping ingress application."
fi

echo "✅ Exposure infrastructure deployment completed successfully."
echo "   Run 'kubectl get ingress -n oficina-ns' to check the ALB status."

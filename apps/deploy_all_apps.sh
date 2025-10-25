#!/bin/bash
# ------------------------------------------------------------
# Script: deploy_all_apps.sh
# Purpose: Deploy Nginx, Redis, and Blog apps into demo-app namespace
# Author: Kuseh Wewoli
# ------------------------------------------------------------

set -e  # Exit immediately if a command exits with a non-zero status

# Namespace for all demo apps
NAMESPACE="demo-apps"

echo "🚀 Starting application deployment in namespace: $NAMESPACE"
echo "------------------------------------------------------------"

# Step 1: Create namespace if it doesn't exist
if ! kubectl get ns $NAMESPACE >/dev/null 2>&1; then
  echo "🛠️  Creating namespace: $NAMESPACE..."
  kubectl create namespace $NAMESPACE
else
  echo "✅ Namespace '$NAMESPACE' already exists."
fi

# Step 2: Deploy Nginx application
echo "📦 Deploying Nginx..."
kubectl apply -f /apps/nginx/nginx-deployment.yaml -n $NAMESPACE
kubectl apply -f /apps/nginx/nginx-svc.yaml -n $NAMESPACE

# Step 3: Deploy Redis application
echo "📦 Deploying Redis..."
kubectl apply -f /apps/redis/redis-deployment.yaml -n $NAMESPACE
kubectl apply -f /apps/redis/redis-svc.yaml -n $NAMESPACE

# Step 4: Deploy Blog application
echo "📦 Deploying Blog app..."
kubectl apply -f /apps/blog/blog-deployment.yaml -n $NAMESPACE
kubectl apply -f /apps/blog/blog-svc.yaml -n $NAMESPACE

# Step 5: Verify deployment status
echo "🔍 Checking deployment status..."
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE

echo "------------------------------------------------------------"
echo "🎉 All demo applications have been successfully deployed in the '$NAMESPACE' namespace."
echo "------------------------------------------------------------"

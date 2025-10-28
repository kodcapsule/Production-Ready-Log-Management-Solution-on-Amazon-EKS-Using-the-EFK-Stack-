#!/bin/bash

# ============================================================================
# Script Name:  deploy_all_apps.sh
# Description:  Deploy Nginx, Redis, and django blog applications to efk cluster 
# Author:       KodeCapsule
# Date:         2024-06-10
# Usage:        ./deploy_all_apps.sh
# ============================================================================

set -e  # Exit on any error
set -o pipefail  # Catch errors in pipes

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
readonly NAMESPACE="demo-apps"


# ----------------------------------------------------------------------------
# Helper Functions
# ----------------------------------------------------------------------------

# Print formatted info messages
print_info() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

# Print formatted success messages
print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# Print formatted error messages
print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# Print section headers
print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

# Check if kubectl is available
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Create namespace if it doesn't exist
create_namespace() {
    print_info "Checking namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "Namespace '$NAMESPACE' already exists"
    else
        print_info "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
        print_success "Namespace '$NAMESPACE' created"
    fi
}

# Deploy an application with deployment and service files
deploy_app() {
    local app_name=$1
    local app_path="${app_name}/"
    echo "$app_path"
    
    print_info "Deploying ${app_name^}..."
    
    if [[ ! -d "$app_path" ]]; then
        print_error "Application directory not found: $app_path"
        return 1
    fi
    
    # Apply deployment
    if [[ -f "${app_path}/${app_name}-deployment.yaml" ]]; then
        kubectl apply -f "${app_path}/${app_name}-deployment.yaml" -n "$NAMESPACE"
    else
        print_error "Deployment file not found for $app_name"
        return 1
    fi
    
    # Apply service
    if [[ -f "${app_path}/${app_name}-svc.yaml" ]]; then
        kubectl apply -f "${app_path}/${app_name}-svc.yaml" -n "$NAMESPACE"
    else
        print_error "Service file not found for $app_name"
        return 1
    fi
    
    print_success "${app_name^} deployed successfully"
}

# Display deployment status
show_deployment_status() {
    print_header "Deployment Status"
    
    print_info "Pods in namespace '$NAMESPACE':"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo ""
    print_info "Services in namespace '$NAMESPACE':"
    kubectl get svc -n "$NAMESPACE" -o wide
    
    echo ""
    print_info "Deployments in namespace '$NAMESPACE':"
    kubectl get deployments -n "$NAMESPACE" -o wide
}

# ----------------------------------------------------------------------------
# Main Execution
# ----------------------------------------------------------------------------

main() {
    print_header "Kubernetes Application Deployment"
    print_info "Target namespace: $NAMESPACE"
    print_info "Applications: Nginx, Redis, Blog"
    
    # Verify prerequisites
    print_info "Checking prerequisites..."
    check_prerequisites
    print_success "Prerequisites validated"
    
    # Create namespace
    create_namespace
    
    # Deploy applications
    print_header "Deploying Applications"
    deploy_app "nginx"
    deploy_app "redis"
    deploy_app "blog"
    
    # Show deployment status
    show_deployment_status
    
    # Final message
    print_header "Deployment Complete"
    print_success "All applications deployed successfully to '$NAMESPACE' namespace!"
    echo ""
}

# Execute main function
main "$@"
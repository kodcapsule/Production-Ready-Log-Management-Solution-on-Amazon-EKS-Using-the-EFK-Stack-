#  


This is a production-ready project that demostrate how you can build Centralized and Scalable log management solution on **Amazon EKS** using the popular **EFK Stack** — **Elasticsearch**, **Fluent Bit**, and **Kibana**. By implementing this project, you will have practical hands-on experience of how to manage logs in a microservice and cloud-native applications. 


## **Table of Contents**

1. [Introduction](#introduction)  
2. [Project Architecture](#project-architecture)  
3. [Prerequisites](#prerequisites)  
4. [Set Up a Kubernetes Cluster](#Set-Up-a-Kubernetes-Cluster])  
      - [Step 1: Create an EKS cluster using eksctl](#Create-an-EKS-cluster-using-eksctl) 
      - [Step 2: install iam-oidc-provider](#install-iam-oidc-provider) 
      - [Step 3: create nodegroup](#create-nodegroup)
      - [Step 4: update-kubeconfig](#update-kubeconfig)
      - [Step 5: Verify cluster connection](#Verify-cluster-connection)
5. [Deploy Sample Applications](#-deploy-sample-applications)
6. [Set Up the EFK Stack](#set-up-the-efk-stack) 
7. [Verification](#verification)  
8. [Cleanup (Optional)](#cleanup-optional)  
9. [Conclusion](#conclusion)
---
## Introduction
In today's modern cloud-native applications, logging is very critical and should not be an afterthought. help Application logs help in troubleshooting and resolving application failure. Unlike smaller applications with lower traffic, for which you can check logs by simply using the `kubectl logs` command to check the logs of a pod straightforwardly, in a microservices architecture, applications usually have hundreds and sometimes thousands of services: using the usual technique to identify and manage logs is practically impossible and inefficient. Then how do we address this challenge?

Well, we need an efficient log management system to quickly locate the information we need when issues arise; EFK Stack to the rescue. When it comes to Kubernetes log management, the EFK stack stands out as a reliable option. EFK, which stands for Elasticsearch, Fluent Bit, and Kibana, simplifies the process of collecting, analysing, and visualising logs. This stack includes a strong set of tools for managing logs across Kubernetes clusters, allowing you to effectively monitor, troubleshoot, and obtain important insights into your applications.

In this project we will dive deep into how to deploy production-ready log management in AWS EKS using the EFK stack. if you are ready, grab a cup of coffee, and let's gather some logs for efficient management and troubleshooting.
---

## Project Architecture
![Project Architecture](./images/CLo.gif)
The architecture consists of:  
- **Amazon EKS Cluster** hosting containerized applications.  
- **Fluent Bit** as a lightweight log collector and forwarder.  
- **Elasticsearch** for log indexing and storage.  
- **Kibana** for log visualization and querying.  
- **Sample applications** Three sample applications, Nginx, Redis and Django blog app deployed into the cluster

---
## Prerequisites

Before you begin, make sure you have the  following prerequisites met:

1. **AWS Account** – You should  have an active AWS account with sufficient permissions to create and manage AWS resources (EKS,EC2 and EBS).  
   👉 [Create an AWS Account](https://aws.amazon.com/resources/create-account/)

2. **AWS CLI** – Installed and configured  with your AWS credentials.  
   👉 [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

3. **kubectl** – Installed and configured to manage your Kubernetes cluster.  
   👉 [Install kubectl](https://kubernetes.io/docs/tasks/tools/)

4. **Helm** – Installed for managing Kubernetes packages and deploying Helm charts.  
   👉 [Install Helm](https://helm.sh/docs/intro/install/)

5. **eksctl** – Installed for creating and managing Amazon EKS clusters.  
   👉 [Install eksctl](https://eksctl.io/installation/)

6. **Knowledge Requirement** – A basic understanding of containers, Kubernetes, and cloud-native application concepts.  
   👉 [Learn the Basics of Kubernetes](https://kubernetes.io/docs/concepts/)

---
## Set Up a Kubernetes Cluster
This section describes how to create and configure a Kubernetes cluster on Amazon EKS using **eksctl**.

### **⚙️ Step 1: Create an EKS Cluster Using eksctl**

Create a new EKS cluster  using the following command:

```bash
eksctl create cluster \
  --name efk-cluster \
  --region us-east-1 \
  --zones=us-east-1a,us-east-1b \
  --without-nodegroup
```

> ⏱️ *Wait patiently as this process may take several minutes, between 15 to 20 minutes.*

---


### **🧰 Step 2: Install IAM OIDC Provider in th cluster**

Associate an IAM OpenID Connect (OIDC) provider with your EKS cluster to enable service account authentication:

```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster efk-cluster \
  --approve
```

Expected output:

```bash
2025-10-25 13:25:06 [ℹ]  will create IAM Open ID Connect provider for cluster "efk-cluster" in "us-east-1"
2025-10-25 13:25:07 [✔]  created IAM Open ID Connect provider for cluster "efk-cluster" in "us-east-1"
```

Verify OIDC configuration:

```bash
aws eks describe-cluster \
--name efk-cluster \
--query "cluster.identity.oidc.issuer" \
--output text
```
Expected output:

```bash
https://oidc.eks.us-east-1.amazonaws.com/id/A3048BC2344DF3FCE082A738E4239522

```

### **Step 3: Create Node Group**

Add node a nodegroup to your cluster 

```bash
eksctl create nodegroup \
  --cluster efk-cluster \
  --region us-east-1 \
  --name workers-1 \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```


### **Step 4: Update Kubeconfig**

Update your local kubeconfig file to connect `kubectl` to your EKS cluster,efk-cluster:

```bash
aws eks update-kubeconfig \
--region us-east-1 \
--name efk-cluster
```
Expected output:

```bash
Updated context arn:aws:eks:us-east-1:650251710981:cluster/efk-cluster in C:\Users\simon\.kube\config
```

Confirm your current context:

```bash
kubectl config current-context
```
Expected output:
```
arn:aws:eks:us-east-1:650251710981:cluster/efk-cluster

```

> 🧠 *This ensures `kubectl` commands are executed against the correct EKS cluster.*


### **Step 5: Verify Cluster Connection**

Verify the health and readiness of your nodes and cluster:

```bash
kubectl get nodes
```

Expected output:

```bash
NAME                             STATUS   ROLES    AGE    VERSION
ip-192-168-48-113.ec2.internal   Ready    <none>   9m4s   v1.32.9-eks-113cf36
ip-192-168-53-185.ec2.internal   Ready    <none>   9m5s   v1.32.9-eks-113cf36
ip-192-168-7-202.ec2.internal    Ready    <none>   9m5s   v1.32.9-eks-113cf36
```

> ✅ *Your Kubernetes cluster is now up and running on Amazon EKS.*

---



## Deploy Sample Applications
In this section, we will deploy a set of sample applications to the Kubernetes cluster.
These applications will generate logs that will be collected, processed, and visualized by the EFK stack. The applications are in the apps directory. 


The following three applications will be deployed into the cluster:

- Nginx: A lightweight web server used to simulate HTTP traffic and access logs.

- Redis: An in-memory data store that produces operational and event logs.

- A Django blog application : A simple web-based application that generates application-level logs. 


### **Step 1: Deploy apps in the cluster**

To deploy these applications i write a script that will automate this process. Navigate to the apps directory and run this command

```bash
  ../deploy_all_apps.sh
```
This command will create a namespace called demo-apps and  deploy  all the apps in that namespace

Expected output:
```bash
```


### **Step 5: Verify all pods are running in the  Cluster**
Very that all your pods are running in the cluster

```bash
kubectl get pods -n demo-apps
```

Expected output:
```bash
NAME                              READY   STATUS    RESTARTS   AGE
blog-app-788df6747c-2k2jm         1/1     Running   0          5m2s
blog-app-788df6747c-k4mfg         1/1     Running   0          5m2s
nginx-deployment-96b9d695-422l4   1/1     Running   0          5m19s
nginx-deployment-96b9d695-bdfpq   1/1     Running   0          5m19s
redis-0                           1/1     Running   0          5m9s

```

> ✅ *Make sure all your  pods are in the running state*

---

## Set Up the EFK Stack


### 🧩 Initial Setup

Elasticsearch is a **stateful application**. To ensure data persistence, you must create an **Amazon EBS (Elastic Block Store) volume** where Elasticsearch can store all logs permanently.

In order for the **EKS cluster** to interact with the EBS volume, some initial configuration is required. Follow the steps below to complete the setup.



**Step 1: Create an IAM Role for the Service Account**  
   This role will grant the necessary permissions for the EBS CSI driver to manage EBS volumes on behalf of Kubernetes.

   ```bash
   eksctl create iamserviceaccount \
   --name ebs-csi-controller-sa \
   --namespace kube-system \
   --cluster efk-cluster \
   --role-name AmazonEKS_EBS_CSI_DriverRole \
   --role-only \
   --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
   --approve
   ```
   
**step 2 : Retrieve the IAM Role ARN**  
   You will need the ARN of the IAM role created in the previous step to associate it with your EKS service account.
   ```bash
   ARN=$(aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole --query 'Role.Arn' --output text)
   ```

**Step 3: Deploy the EBS CSI Driver**  
   The EBS Container Storage Interface (CSI) driver enables dynamic provisioning and management of EBS volumes for your Kubernetes workloads.

```bash
eksctl create addon --cluster efk-cluster \
--name aws-ebs-csi-driver --version latest \
--service-account-role-arn $ARN --force
```
For more details on EBS CSI driver read [Use Kubernetes volume storage with Amazon EBS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

**Step 4: Create a Namespace for Logging**  
   Create a  namespace named `logging` where all EFK components will be deployed.  

  ```bash
  kubectl create namespace logging
  ```


To install the EFK stack in our cluster, we will use helm, make sure you have helm installed
### Deploy Elasticserach in K8S cluster
**Step 1: Add  Elastic charts repository**
```bash
helm repo add elastic https://helm.elastic.co
helm repo update
```

 **Step 2: Install the   chart**

```bash
helm install elasticsearch \
 --set replicas=1 \
 --set volumeClaimTemplate.storageClassName=gp2 \
 --set persistence.labels.enabled=true elastic/elasticsearch -n logging
```

Preferably you can install Elasticesearch using the operator. 
 **Step 3: Retrieve Elasticsearch Username & Password**

```bash
 # for username
kubectl get secrets --namespace=logging elasticsearch-master-credentials -ojsonpath='{.data.username}' | base64 -d
# for password
kubectl get secrets --namespace=logging elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
```



### Deploy Kibana in K8S cluster
Since kibana is part of 
 **Step 1: Install the   chart**
 ```bash
 helm install kibana elastic/kibana      
 ```
### Deploy  Fluentbit in the K8S cluster

**Step 1: Add  the Fluent Helm charts repository**

Use the following command to add the Fluent Helm charts repository
```bash
helm repo add fluent https://fluent.github.io/helm-charts 
```
 validate that the repo was added
```bash
helm search repo fluent
```
 **Step 2: Install the  default chart**
```bash
helm upgrade --install fluent-bit fluent/fluent-bit
```
For more details ablout installing Fluent bit in K8S cluster refere to [Download and install Fluent Bit](https://docs.fluentbit.io/manual/installation/downloads/kubernetes#fluent-bit.conf)
## Verification
## Cleanup 
## Conclusion 
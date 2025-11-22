#  Production-Ready EFK Stack Log Management for Amazon EKS - Elasticsearch, Fluent Bit, Kibana


This is a production-ready project that demostrate how you can build Centralized and Scalable log management solution on **Amazon EKS** using the popular **EFK Stack** - **Elasticsearch**, 
- **Fluent Bit** and
- **Kibana**.
 By implementing this project, you will have practical hands-on experience of how to manage logs in a microservice and cloud-native applications. 

---

## **Table of Contents**

1. [Introduction](#introduction)  
2. [Project Architecture](#project-architecture)  
3. [Prerequisites](#prerequisites)  
4. [Set Up a Kubernetes Cluster](#Set-Up-a-Kubernetes-Cluster])    
5. [Deploy Sample Applications](#-deploy-sample-applications)
6. [Set Up the EFK Stack](#set-up-the-efk-stack)  
7. [Cleanup (Optional)](#cleanup-optional)  
8. [Conclusion](#conclusion)

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
This section describes how to create and configure a Kubernetes cluster on Amazon EKS using **eksctl**. `eksctl` is a command-line utility tool that automates and simplifies the process of creating, managing, and operating Amazon Elastic Kubernetes Service (Amazon EKS) clusters. 
If you want to learn more about the **ekctl** utility visit the official docs [What is Eksctl?](https://docs.aws.amazon.com/eks/latest/eksctl/what-is-eksctl.html)

### **⚙️ Step 1: Create an EKS Cluster Using eksctl**
 
Create a new EKS cluster with any node group using the following command:

```bash
eksctl create cluster \
  --name efk-cluster \
  --region us-east-1 \
  --zones=us-east-1a,us-east-1b \
  --without-nodegroup
```

> ⏱️ *Wait patiently as this process may take several minutes, between 15 to 20 minutes.*


If you have done everything correctly you should get the ouput below indicating that the cluster has been created successfully. I have trancated the output for readerbility.

Expected output.  

```bash
2025-11-15 23:42:34 [ℹ]  creating addon: vpc-cni
2025-11-15 23:42:34 [ℹ]  successfully created addon: vpc-cni
2025-11-15 23:44:39 [ℹ]  waiting for the control plane to become ready
2025-11-15 23:44:47 [✔]  saved kubeconfig as "C:\\Users\\simon\\.kube\\config"
2025-11-15 23:44:47 [ℹ]  no tasks
2025-11-15 23:44:47 [✔]  all EKS cluster resources for "efk-cluster" have been created
2025-11-15 23:45:01 [ℹ]  kubectl command should work with "C:\\Users\\simon\\.kube\\config", try 'kubectl get nodes'
2025-11-15 23:45:01 [✔]  EKS cluster "efk-cluster" in "us-east-1" region is ready
```



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

Add node a nodegroup to your cluster. To learn more about EKS managed node groups and why they are needed, read the EKS docs [Simplify node lifecycle with managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) 

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
This command will create 3 EC2 instances as worker nodes in the data plane of the cluster. I have trancated the output for readerbility.

Expected output:

```bash
2025-11-15 23:53:51 [ℹ]  nodegroup "workers-1" has 3 node(s)
2025-11-15 23:53:51 [ℹ]  node "ip-192-168-2-81.ec2.internal" is ready
2025-11-15 23:53:51 [ℹ]  node "ip-192-168-4-18.ec2.internal" is ready
2025-11-15 23:53:51 [ℹ]  node "ip-192-168-48-127.ec2.internal" is ready
2025-11-15 23:53:51 [✔]  created 1 managed nodegroup(s) in cluster "efk-cluster"
2025-11-15 23:53:52 [ℹ]  checking security group configuration for all nodegroups
2025-11-15 23:53:52 [ℹ]  all nodegroups have up-to-date cloudformation templates
```

### **Step 4: Update Kubeconfig**

Update your local kubeconfig file to  connect `kubectl` to your EKS cluster,efk-cluster:

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

> 🧠 *This ensures `kubectl` commands are executed against the efk-cluster EKS cluster.*


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
These applications will generate logs that will be collected, processed, and visualized by the EFK stack. The applications are in the `apps` directory. 

The following three applications will be deployed into the cluster:

- Nginx: A lightweight web server used to simulate HTTP traffic and access logs.

- Redis: An in-memory data store that produces operational and event logs.

- A Django blog application : A simple web-based application that generates application-level logs. 


### **Step 1: Deploy apps in the cluster**

To deploy these application, a script  will automate this process, since the focus is on log management. Navigate to the `apps` directory and run this command

```bash
  ./deploy_all_apps.sh
```
This command will create a namespace called demo-apps and  deploy  all the apps in that namespace. Yo can take a look at the script to better understand it. 

```bash
============================================================
  Deployment Status
============================================================

[INFO] Pods in namespace 'demo-apps':
NAME                              READY   STATUS              RESTARTS   AGE   IP               NODE                             NOMINATED NODE   READINESS GATES
blog-app-788df6747c-2f58z         0/1     ContainerCreating   0          5s    <none>           ip-192-168-48-127.ec2.internal   <none>           <none>
blog-app-788df6747c-ndvt8         0/1     ContainerCreating   0          5s    <none>           ip-192-168-2-81.ec2.internal     <none>           <none>
nginx-deployment-96b9d695-hpttg   1/1     Running             0          21s   192.168.1.251    ip-192-168-2-81.ec2.internal     <none>           <none>
nginx-deployment-96b9d695-kvqmm   1/1     Running             0          21s   192.168.39.30    ip-192-168-48-127.ec2.internal   <none>           <none>
redis-0                           1/1     Running             0          12s   192.168.27.164   ip-192-168-4-18.ec2.internal     <none>           <none>


[INFO] Services in namespace 'demo-apps':
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE   SELECTOR
blog-app        ClusterIP   10.100.41.149    <none>        80/TCP     5s    app=blog-app
nginx-service   ClusterIP   10.100.237.242   <none>        80/TCP     19s   app=nginx
redis           ClusterIP   10.100.241.16    <none>        6379/TCP   12s   app=redis


[INFO] Deployments in namespace 'demo-apps':
NAME               READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                    SELECTOR
blog-app           2/2     2            2           11s   blog-app     kodecapsule/django-blog-app:blue-server   app=blog-app
nginx-deployment   2/2     2            2           26s   nginx        nginx:latest                              app=nginx

============================================================
  Deployment Complete
============================================================
[SUCCESS] All applications deployed successfully to 'demo-apps' namespace!

```
### **Step 2: Verify all pods are running in the  Cluster**
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
   
Expected output:
```bash
2025-11-16 00:24:51 [ℹ]  1 iamserviceaccount (kube-system/ebs-csi-controller-sa) was included (based on the include/exclude rules)
2025-11-16 00:24:51 [!]  serviceaccounts in Kubernetes will not be created or modified, since the option --role-only is used
2025-11-16 00:24:51 [ℹ]  1 task: { create IAM role for serviceaccount "kube-system/ebs-csi-controller-sa" }
2025-11-16 00:24:51 [ℹ]  building iamserviceaccount stack "eksctl-efk-cluster-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa"
2025-11-16 00:24:51 [ℹ]  deploying stack "eksctl-efk-cluster-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa"
2025-11-16 00:25:00 [ℹ]  waiting for CloudFormation stack "eksctl-efk-cluster-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa"
2025-11-16 00:25:44 [ℹ]  waiting for CloudFormation stack "eksctl-efk-cluster-addon-iamserviceaccount-kube-system-ebs-csi-controller-sa"
```


**Step 2 : Retrieve the IAM Role ARN**  
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
Expected CLI output:
```bash
2025-11-16 00:31:55 [ℹ]  Kubernetes version "1.32" in use by cluster "efk-cluster"
2025-11-16 00:31:56 [ℹ]  IRSA is set for "aws-ebs-csi-driver" addon; will use this to configure IAM permissions
2025-11-16 00:31:56 [!]  the recommended way to provide IAM permissions for "aws-ebs-csi-driver" addon is via pod identity associations; after addon creation is completed, run `eksctl utils migrate-to-pod-identity`
2025-11-16 00:31:56 [ℹ]  using provided ServiceAccountRoleARN "arn:aws:iam::650251710981:role/AmazonEKS_EBS_CSI_DriverRole"
2025-11-16 00:31:56 [ℹ]  creating addon: aws-ebs-csi-driver
```

For more details on EBS CSI driver read [Use Kubernetes volume storage with Amazon EBS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

**Step 4: Create a Namespace for Logging**  
   Create a  namespace named `logging` where all EFK components will be deployed.  

  ```bash
  kubectl create namespace logging
  ```


To install the EFK stack in our cluster, we will use helm, make sure you have helm installed
### Deploy Elasticserach in the efk-cluster
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

Expected CLI output:

```bash
NAME: elasticsearch
LAST DEPLOYED: Sun Nov 16 00:42:35 2025
NAMESPACE: logging
STATUS: deployed
REVISION: 1
NOTES:
1. Watch all cluster members come up.
  $ kubectl get pods --namespace=logging -l app=elasticsearch-master -w
2. Retrieve elastic user's password.
  $ kubectl get secrets --namespace=logging elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Test cluster health using Helm test.
  $ helm --namespace=logging test elasticsearch
```

Preferably you can install Elasticesearch using the operator. 


**Step 3: Retrieve Elasticsearch Username & Password**
The log forwarder, Fluent bit will need to authenticate to elasticserach to farward the logs it gathers. 
```bash
 # for username
kubectl get secrets --namespace=logging elasticsearch-master-credentials -ojsonpath='{.data.username}' | base64 -d
# for password
kubectl get secrets --namespace=logging elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
```

### Deploy Kibana in K8S cluster
  **Step 1: Install the   chart**
 ```bash
 helm install kibana --set service.type=LoadBalancer elastic/kibana -n logging     
 ```
Expected CLI output:

 ```bash
 NAME: kibana
LAST DEPLOYED: Sun Nov 16 00:47:30 2025
NAMESPACE: logging
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
1. Watch all containers come up.
  $ kubectl get pods --namespace=logging -l release=kibana -w
2. Retrieve the elastic user's password.
  $ kubectl get secrets --namespace=logging elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d
3. Retrieve the kibana service account token.
  $ kubectl get secrets --namespace=logging kibana-kibana-es-token -ojsonpath='{.data.token}' | base64 -d
 ```
### Deploy  Fluentbit in the K8S cluster

**Step 1: Add  the Fluent Helm charts repository**
Before deploying Fuent bit to the cluster, make sure you update the output section of `fluentbit-values.yaml` with the user name and password for Elasticsearch. 

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
helm install fluent-bit fluent/fluent-bit -f efk/fluentbit-values.yaml -n logging
```
Expected CLI output:
```bash
NAME: fluent-bit
LAST DEPLOYED: Sun Nov 16 00:59:26 2025
NAMESPACE: logging
STATUS: deployed
REVISION: 1
NOTES:
Get Fluent Bit build information by running these commands:

export POD_NAME=$(kubectl get pods --namespace logging -l "app.kubernetes.io/name=fluent-bit,app.kubernetes.io/instance=fluent-bit" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace logging port-forward $POD_NAME 2020:2020
curl http://127.0.0.1:2020
```
For more details ablout installing Fluent bit in K8S cluster refere to [Download and install Fluent Bit](https://docs.fluentbit.io/manual/installation/downloads/kubernetes#fluent-bit.conf)



### Verification
verify that all the EFK stack pods are running 
```bash
 kubectl get po -n logging
```
```bash
NAME                           READY   STATUS    RESTARTS   AGE
elasticsearch-master-0         1/1     Running   0          19m
fluent-bit-2g946               1/1     Running   0          2m51s
fluent-bit-dfch7               1/1     Running   0          2m51s
fluent-bit-pk2m9               1/1     Running   0          2m51s
kibana-kibana-894d6648-phvct   1/1     Running   0          14m
```
confirm that all serices are ok
```bash
kubectl get svc -n logging
```

```bash
NAME                            TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)             AGE
elasticsearch-master            ClusterIP      10.100.213.252   <none>                                                                    9200/TCP,9300/TCP   22m
elasticsearch-master-headless   ClusterIP      None             <none>                                                                    9200/TCP,9300/TCP   22m
fluent-bit                      ClusterIP      10.100.236.186   <none>                                                                    2020/TCP            6m1s
kibana-kibana                   LoadBalancer   10.100.110.193   acbc27c5d340f4065a3b14d34c4d42d6-1178792962.us-east-1.elb.amazonaws.com   5601:32444/TCP      17m
```
 To verify the setup, access the Kibana dashboard by entering the `LoadBalancer DNS name followed by :5601 in your browser.
        http://LOAD_BALANCER_DNS_NAME:5601
  ```bash
acbc27c5d340f4065a3b14d34c4d42d6-1178792962.us-east-1.elb.amazonaws.com:5601
```
The kubana login page will appear login with the username and password you got from Elasticsearch. 
Once logged in, create a new data view in Kibana and explore the logs collected from your Kubernetes cluster.


## Cleanup 
 **Step 1: uninstall the  helm charts**

```bash

helm uninstall fluent-bit -n logging

helm uninstall elasticsearch -n logging

helm uninstall kibana -n logging

```
**Step 2: Delete the cluster**

```bash
eksctl delete cluster --name efk-cluster
```
---
## Conclusion 
In this project, we have successfully installed the EFK stack in our Kubernetes cluster, which includes 
- Elasticsearch for storing logs
- Fluentbit for collecting and forwarding logs
- Kibana for visualizing logs.
The EFK stack is one of the most commond stack that is used for log management ,by implementing this project, you  have gained practical hands-on experience of how to manage logs in a microservice and cloud-native applications.
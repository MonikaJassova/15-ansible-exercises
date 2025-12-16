#### This project is for the Devops bootcamp exercise for 
#### "Configuration Management with Ansible"

## Java Application Deployment

1. Created a server on DigitalOcean (a droplet in the closest region with 1 GB memory and my SSH key added)
1. Added droplet's IP to [hosts file](hosts) (in webserver group)
1. Wrote [deploy-java.yaml](./deploy-java.yaml) Ansible Playbook and ran it (`ansible-playbook deploy-java.yaml`) to
    - install Java 17 on server
    - create a new Linux user
    - remove any existing jar files
    - kill any existing Java processes
    - copy over jar artifact
    - start the Java app with that user
    - verify the app is running successfully and print the result

## Pushing an Artifact to Nexus

1. Wrote [push-nexus.yaml](./push-nexus.yaml) Ansible Playbook and ran it (`ansible-playbook push-nexus.yaml`) to
    - ensure provided jar file exists
    - upload the file to a Maven repository on Nexus server and print the result

## Installing Jenkins (different OS flavours)

1. Wrote [install-jenkins.yaml](install-jenkins.yaml) and ran it (`ansible-playbook install-jenkins.yaml -e "ec2_image=ami-0a6793a25df710b06 ansible_user=ec2-user host_os=amazon"` or `ansible-playbook install-jenkins.yaml -e "ec2_image=ami-004e960cde33f9146 ansible_user=ubuntu host_os=ubuntu"`) to
    - create a new EC2 instance based on Amazon Linux or Ubuntu image
    - install and run Jenkins on EC2
    - install nodejs, npm and docker on EC2 to be available for Jenkins builds

## Installing Jenkins as a Docker Container

1. Wrote [install-jenkins-docker.yaml](install-jenkins-docker.yaml) and ran it (`ansible-playbook install-jenkins-docker.yaml`) to
    - install Docker (Ubuntu machine assumed) and start it
    - prepare Docker volume for Jenkins home
    - start Jenkins as a Docker container with volumes for Jenkins home and Docker itself to be able to execute Docker commands inside Jenkins

## Provisioning and configuring Web server and Database server

1. Wrote [provision-ansible.yaml](provision-ansible.yaml) and ran it (`ansible-playbook provision-ansible.yaml`) to
    - provision and configure a dedicated Ansible control server on EC2 in a public subnet of a separate VPC
1. Wrote [provision-web-db.yaml](provision-web-db.yaml) and ran it (`ansible-playbook provision-web-db.yaml`) to
    - provision EC2 instances for DB and web servers (DB server created in a private subnet of the same VPC as Ansible server, with NAT gateway to download stuff from Internet)
1. Wrote [configure-ansible.yaml](configure-ansible.yaml) and ran it (`ansible-playbook -i inventory_aws_ec2.yaml configure-ansible.yaml`) to
    - configure Ansible server with all necessary tools (Ansible + boto3 with AWS credentials)
    - copy necessary Ansible playbooks and configuration for execution (private SSH keys to web and DB server)
1. Wrote and ran [configure-web-db.yaml](configure-web-db.yaml) and executed from the Ansible control server (because we can't access the database private IP address from outside VPC) (`ansible-playbook configure-web-db.yaml`) to
    - install and start MySQL server on the EC2 instance without a public IP address using an existing mysql role
    - deploys and runs the Java web application on another EC2 instance

## Deploying Java MySQL Application in Kubernetes

1. Added [Dockerfile](Dockerfile) for Java app, built and pushed image to ECR repository
1. Created K8s configuration files for deployments (MySQL DB app with 1 replica), services for Java and MySQL applications as well as configMap and Secret for the DB connectivity.
1. Created K8s configuration files for Java application with its dependencies, and ingress for the Java app.
1. Created an EKS cluster using eksctl: `eksctl create cluster -f cluster.yaml`
1. Created a kubeconfig file with EKS cluster info for Ansible: `aws eks update-kubeconfig --name cluster-ansible --region eu-central-1 --kubeconfig kubeconfig_cluster-ansible`
1. Installed required dependencies for [kubernetes.core.k8s module](https://docs.ansible.com/projects/ansible/latest/collections/kubernetes/core/k8s_module.html#ansible-collections-kubernetes-core-k8s-module): `pip3 install pyyaml kubernetes jsonpatch --user`
1. Installed Ansible Galaxy collection for kubernetes: `ansible-galaxy collection install kubernetes.core`
1. Wrote [deploy-k8s.yaml](deploy-k8s.yaml) playbook to
    - deploy everything in [k8s folder](./k8s/) to the EKS cluster (plus nginx Ingress Controller as a Helm chart)

## Deploying MySQL Chart in Kubernetes

1. Wrote [deploy-mysql.yaml](deploy-mysql.yaml) and ran it (`ansible-playbook deploy-mysql.yaml`) to
    - deploy a MySQL DB with 3 replicas using a helm chart in place of the currently running single MySQL instance

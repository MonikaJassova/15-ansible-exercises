#### This project is for the Devops bootcamp exercise for

#### "Configuration Management with Ansible"

## 1. Building & Deploying a Java Artifact

Prerequisites:

- A T-Cloud Public ECS server (Ubuntu image) with 1 GB memory and SSH key added, its IP registered in the [hosts file](hosts) under the `webserver` group (with `ansible_user` and `ansible_ssh_private_key_file`)
- Gradle (8.x, see [mise.toml](mise.toml)) to build the Java app
- App and DB connection variables in [project-vars](project-vars)

1. Wrote [1-deploy-java.yaml](./1-deploy-java.yaml) Ansible Playbook and ran it (`ansible-playbook 1-deploy-java.yaml`) to
   - build the app locally (`gradle clean build`)
   - install Java 17 runtime environment on server
   - create a new Linux user
   - remove any existing jar files
   - kill any existing Java processes
   - copy over jar artifact
   - start the Java app with that user
   - verify the app is running successfully and print the result

## 2. Pushing the Java Artifact to Nexus

Prerequisites:

- The jar already built at `build/libs/{{ app_name }}.jar` (run playbook 1, or `gradle clean build`) — the playbook fails by design if it is missing
- Nexus URL, user and password in [project-vars](project-vars)

1. Wrote [2-push-nexus.yaml](./2-push-nexus.yaml) Ansible Playbook and ran it (`ansible-playbook 2-push-nexus.yaml`) to
   - ensure provided jar file exists
   - upload the file to a Maven repository on Nexus server and print the result

## 3. Installing Jenkins on an ECS (different OS flavours)

Prerequisites:

- OpenStack credentials for T-Cloud Public in `~/.config/openstack/clouds.yaml`, under a cloud name matching `tcloud_cloud` in [project-vars](project-vars) (default `eu-de`) — the playbook passes `cloud:` explicitly, so no `OS_CLOUD`/`OS_AUTH_URL` env vars are needed
- Ansible (14.x, see [mise.toml](mise.toml)) with the `openstack.cloud` collection and `openstacksdk<4` installed in the ansible venv (openstacksdk 4.x is incompatible with openstack.cloud 2.x)
- SSH private key for the `tcloud_key_name` key pair (`tcloud_private_key` in [project-vars](project-vars), default `~/.ssh/id_rsa`)
- T-Cloud network, OS, security group (opens 22 and 8080) and per-flavour images configured in [project-vars](project-vars)

1. Wrote [3-install-jenkins.yaml](3-install-jenkins.yaml) and ran it (`ansible-playbook 3-install-jenkins.yaml -e os_flavour=ubuntu` or `ansible-playbook 3-install-jenkins.yaml -e os_flavour=fedora`) to
   - provision a new T-Cloud ECS server and attach a floating IP
   - install and run Jenkins (with Java 21, required by current Jenkins LTS) on the server
   - install nodejs, npm and docker on the server to be available for Jenkins builds
   - print the Jenkins admin password at the end

## 4. Installing Jenkins as a Docker Container

Prerequisites:

- A T-Cloud Public ECS server (Ubuntu image) with SSH key added, its IP registered in the [hosts file](hosts) under the `jenkins` group (with `ansible_user` and `ansible_ssh_private_key_file`)
- The `community.docker` Ansible collection (for `docker_container`/`docker_volume` modules)

1. Wrote [4-install-jenkins-docker.yaml](4-install-jenkins-docker.yaml) and ran it (`ansible-playbook 4-install-jenkins-docker.yaml`) to
    - install Docker CE (from the official Docker apt repo, Ubuntu machine assumed) and start it
    - prepare Docker volume for Jenkins home
    - start Jenkins as a Docker container with volumes for Jenkins home and Docker itself (docker socket + CLI) to be able to execute Docker commands inside Jenkins
    - print the Jenkins initial admin password at the end

## 5. Provisioning and configuring Web server and Database server

1. Wrote [5-provision-ansible.yaml](5-provision-ansible.yaml) and ran it (`ansible-playbook 5-provision-ansible.yaml`) to
    - provision and configure a dedicated Ansible control server on EC2 in a public subnet of a separate VPC
1. Wrote [provision-web-db.yaml](provision-web-db.yaml) and ran it (`ansible-playbook provision-web-db.yaml`) to
    - provision EC2 instances for DB and web servers (DB server created in a private subnet of the same VPC as Ansible server, with NAT gateway to download stuff from Internet)
1. Wrote [configure-ansible.yaml](configure-ansible.yaml) and ran it (`ansible-playbook -i inventory_aws_ec2.yaml configure-ansible.yaml`) to
    - configure Ansible server with all necessary tools (Ansible + boto3 with AWS credentials)
    - copy necessary Ansible playbooks and configuration for execution (private SSH keys to web and DB server)
1. Wrote and ran [configure-web-db.yaml](configure-web-db.yaml) and executed from the Ansible control server (because we can't access the database private IP address from outside VPC) (`ansible-playbook configure-web-db.yaml`) to
    - install and start MySQL server on the EC2 instance without a public IP address using an existing mysql role
    - deploys and runs the Java web application on another EC2 instance

## 6. Deploying Java MySQL Application in Kubernetes

1. Added [Dockerfile](Dockerfile) for Java app, built and pushed image to ECR repository
1. Created K8s configuration files for deployments (MySQL DB app with 1 replica), services for Java and MySQL applications as well as configMap and Secret for the DB connectivity.
1. Created K8s configuration files for nginx-ingress controller chart and ingress for the java app.
1. Created an EKS cluster using eksctl: `eksctl create cluster -f cluster.yaml`
1. Wrote [deploy-k8s.yaml](deploy-k8s.yaml) playbook to
    - deploy everything in the EKS cluster

## 7. Deploying MySQL Chart in Kubernetes

1. Wrote [deploy-mysql.yaml](deploy-mysql.yaml) and ran it (`ansible-playbook deploy-mysql.yaml`) to
    - deploy a MySQL DB with 3 replicas using a helm chart in place of the currently running single MySQL instance

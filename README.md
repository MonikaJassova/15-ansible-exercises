#### This project is for the Devops bootcamp exercise for

#### "Configuration Management with Ansible"

## 1. Building & Deploying a Java Artifact

Prerequisites:

- A T Cloud Public ECS server (Ubuntu image) with 1 GB memory and SSH key added, its IP registered in the [hosts file](hosts) under the `webserver` group (with `ansible_user` and `ansible_ssh_private_key_file`)
- Gradle (8.x, see [mise.toml](mise.toml)) to build the Java app
- App and DB connection variables in [project-vars](project-vars) and vault-encrypted [secrets.yaml](secrets.yaml)

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
- Nexus URL and user in [project-vars](project-vars), password in vault-encrypted [secrets.yaml](secrets.yaml)

1. Wrote [2-push-nexus.yaml](./2-push-nexus.yaml) Ansible Playbook and ran it (`ansible-playbook 2-push-nexus.yaml`) to
   - ensure provided jar file exists
   - upload the file to a Maven repository on Nexus server and print the result

## 3. Installing Jenkins on an ECS (different OS flavours)

Prerequisites:

- OpenStack credentials for T Cloud Public in `~/.config/openstack/clouds.yaml`, under a cloud name matching `tcloud_cloud` in [project-vars](project-vars) (default `eu-de`) — the playbook passes `cloud:` explicitly, so no `OS_CLOUD`/`OS_AUTH_URL` env vars are needed
- Ansible (14.x, see [mise.toml](mise.toml)) with the `openstack.cloud` collection and `openstacksdk<4` installed in the ansible venv (openstacksdk 4.x is incompatible with openstack.cloud 2.x)
- SSH private key for the `tcloud_key_name` key pair (`tcloud_private_key` in [project-vars](project-vars), default `~/.ssh/id_rsa`)
- T Cloud network, OS, security group (opens 22 and 8080) and per-flavour images configured in [project-vars](project-vars)

1. Wrote [3-install-jenkins.yaml](3-install-jenkins.yaml) and ran it (`ansible-playbook 3-install-jenkins.yaml -e os_flavour=ubuntu` or `ansible-playbook 3-install-jenkins.yaml -e os_flavour=fedora`) to
   - provision a new T Cloud ECS server and attach a floating IP
   - install and run Jenkins (with Java 21, required by current Jenkins LTS) on the server
   - install nodejs, npm and docker on the server to be available for Jenkins builds
   - print the Jenkins admin password at the end

## 4. Installing Jenkins as a Docker Container

Prerequisites:

- A T Cloud Public ECS server (Ubuntu image) with SSH key added, its IP registered in the [hosts file](hosts) under the `jenkins` group (with `ansible_user` and `ansible_ssh_private_key_file`)
- The `community.docker` Ansible collection (for `docker_container`/`docker_volume` modules)

1. Wrote [4-install-jenkins-docker.yaml](4-install-jenkins-docker.yaml) and ran it (`ansible-playbook 4-install-jenkins-docker.yaml`) to
    - install Docker CE (from the official Docker apt repo, Ubuntu machine assumed) and start it
    - prepare Docker volume for Jenkins home
    - start Jenkins as a Docker container with volumes for Jenkins home and Docker itself (docker socket + CLI) to be able to execute Docker commands inside Jenkins
    - print the Jenkins initial admin password at the end

## 5. Provisioning and Configuring Web Server and Database Server

Prerequisites:

- OpenStack credentials for T Cloud Public in `~/.config/openstack/clouds.yaml`, under a cloud name matching `tcloud_cloud` in [project-vars](project-vars) (default `eu-de`)
- Ansible (14.x, see [mise.toml](mise.toml)) with the `openstack.cloud` collection and `openstacksdk<4` installed in the ansible venv (openstacksdk 4.x is incompatible with openstack.cloud 2.x)
- The `opentelekomcloud.cloud` collection and the `otcextensions` Python package in the same venv (OTC NAT gateway API, used in [5-provision-ansible.yaml](5-provision-ansible.yaml))
- SSH private key for the `tcloud_key_name` key pair (`tcloud_private_key` in [project-vars](project-vars))
- VPC (two networks, router + NAT gateway) in [project-vars](project-vars) and DB connection variables in [project-vars](project-vars) / vault-encrypted [secrets.yaml](secrets.yaml)

1. Wrote [5-provision-ansible.yaml](5-provision-ansible.yaml) and ran it (`ansible-playbook 5-provision-ansible.yaml`) to
   - create a dedicated T Cloud VPC: a public and a private network, plus a router with an external gateway
   - create an OTC NAT gateway with an SNAT rule for the private network, so servers on it can reach the Internet (the router's own SNAT is not enough on T Cloud Public)
   - provision a dedicated Ansible control server on the public network with a public EIP
1. Wrote [5-configure-ansible.yaml](5-configure-ansible.yaml) and ran it (`ansible-playbook -i inventory_openstack.yaml 5-configure-ansible.yaml`) to
   - configure the Ansible control server with all necessary tools (Ansible, OpenStack SDK, collections and the mysql role)
   - copy the playbooks, `project-vars`, `ansible.cfg`, the app jar, OpenStack credentials and the SSH private key for the web and DB servers to the control server
1. Wrote [5-provision-web-db.yaml](ansible/5-provision-web-db.yaml) and ran it from the Ansible control server (`ansible-playbook -i localhost 5-provision-web-db.yaml`) to
   - provision the web server (public network, with an EIP) and the DB server (private network, no public IP, Internet egress via the NAT gateway)
   - write the `inventory-web-db` inventory file for the web and DB servers
1. Wrote and ran [5-configure-web-db.yaml](ansible/5-configure-web-db.yaml) from the Ansible control server (the DB private IP is not reachable from outside the VPC) (`ansible-playbook -i inventory-web-db 5-configure-web-db.yaml`) to
   - install and start MySQL on the DB server using an existing mysql role, create the app database and user and seed the `team_members` table (idempotent via `INSERT IGNORE`)
    - deploy and run the Java web application on the web server (it reads the database over the VPC), and verify the app responds on port 8080

## 7. Deploying the Java + MySQL App to T-Cloud CCE (Kubernetes)

Prerequisites:

- A CCE cluster on T-Cloud Public (region `eu-de`), created with the Terraform env `environments/k8s` in the `12-terraform-exercises` repo (VPC + NAT, 3x `s3.large.2` nodes, Everest CSI → StorageClass `csi-disk`)
- A kubeconfig for the cluster's public API endpoint (`https://<API-EIP>:5443`), generated with `mise exec -- bash generate-kubeconfig.sh k8s` in that repo; path set as `kubeconfig_path` in [project-vars](project-vars)
- Local `podman` for building and pushing the image (this machine uses podman, not docker)
- A TCP SWR registry org + repo with a temporary login (SWR console → Generate Login Command, 24 h validity): `registry_host`/`registry_org` in [project-vars](project-vars), `registry_user`/`registry_password` in vault-encrypted [secrets.yaml](secrets.yaml)
- Ansible (14.x) with the `kubernetes.core` and `containers.podman` collections

1. Wrote [7-deploy-k8s.yaml](./7-deploy-k8s.yaml) and ran it (`ansible-playbook 7-deploy-k8s.yaml`) to
    - build the app locally (`gradle clean build`)
    - build the image from [Dockerfile](Dockerfile) (`eclipse-temurin:17-jre` + the jar from `settings.gradle` rootProject.name) and push it to SWR (`swr.eu-de.otc.t-systems.com/test2/java-mysql-app:1.0-SNAPSHOT`)
    - create the `myapp` namespace and a `registry-creds` pull secret
    - install the `ingress-nginx` Helm chart into the `ingress` namespace with a public OTC ELB (`elb.class: union`, `elb.autocreate` public EIP), with a rescue that removes the admission webhook on the known first-install failure and retries
    - deploy the db ConfigMap/Secret, the `team_members` seed ConfigMap, a single-replica MySQL (port 3306, seed mounted at `/docker-entrypoint-initdb.d`) and the Java app (templated from [k8s/java-app.yaml.j2](k8s/java-app.yaml.j2))
    - deploy the [Ingress](k8s/ingress.yaml) (no host, `pathType: Prefix`, so the app is reachable directly via the ELB IP)
    - wait for MySQL to be Ready and the Java deployment to be Available, then print the app URL

   Verified: `curl http://<ELB-IP>/get-data` returns the seeded `team_members` rows (alice/bob/charlie) and `curl http://<ELB-IP>/` returns 200.

## 8. Replacing MySQL with a 3-Replica Bitnami Helm Chart

Prerequisites:

- Exercise 7 completed (single-replica MySQL + Java app deployed, ELB IP known)

1. Wrote [8-deploy-mysql.yaml](./8-deploy-mysql.yaml) and ran it (`ansible-playbook 8-deploy-mysql.yaml`) to
    - remove the single-replica MySQL deployment and service
    - add the Bitnami Helm repository and install the `mysql` chart (pinned 9.4.0, `bitnamilegacy/mysql:8.0.30`) as `mysql-release` with `architecture: replication` (1 primary + 2 secondaries), per-replica RWO PVCs on `csi-disk` and `team_members` seeded via top-level `initdbScripts` ([k8s-helm/mysql-chart-values-tcp.yaml](k8s-helm/mysql-chart-values-tcp.yaml))
    - update the `db-config` ConfigMap to the chart primary service DNS name (`mysql-release-primary.myapp`)
    - redeploy the Java app (a `restartedAt` annotation, re-evaluated on every run, forces a rolling restart so the pods pick up the new DB service name) and wait until it is Available again

    Verified: `mysql-release-primary-0` + 2 secondaries Running with 3 Bound `csi-disk` PVCs; both secondaries show `Replica_IO_Running: Yes`, `Replica_SQL_Running: Yes`, `Seconds_Behind_Source: 0`; `curl http://<ELB-IP>/get-data` still returns the seeded rows.

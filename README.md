#### This project is for the Devops bootcamp exercise for

#### "Configuration Management with Ansible"

## 1. Building & Deploying a Java Artifact

Prerequisites:

- A T Cloud Public ECS server (Ubuntu image) with 1 vCPU, 1 GB memory and SSH key added, its IP registered in the [hosts file](hosts) under the `webserver` group (with `ansible_user` and `ansible_ssh_private_key_file`)
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
   - check whether the app process is running and print the result

    The app runs as the Linux user defined by `linux_user` in [project-vars](project-vars) (default `monika`). To deploy with a different user: `ansible-playbook 1-deploy-java.yaml -e linux_user=testuser` — the user is created if missing, the jar is placed in that user's home, and any existing instance is stopped first (the stop task is not user-scoped, since all instances share port 8080).

    Note: the app needs a reachable MySQL database to stay up (the database is introduced in Exercise 5). In Exercise 1 `db_server` is still a placeholder, so the JVM exits shortly after start — this playbook verifies the *deployment* (jar copied, start attempted), not app health.

## 2. Pushing the Java Artifact to Nexus

Prerequisites:

- The jar already built at `build/libs/{{ app_name }}.jar` (run playbook 1, or `gradle clean build`) — the playbook fails by design if it is missing
- ECS provisioned (2 vCPU, 8GB RAM, 20GB disk) and Nexus server configured (e.g. with [2-deploy-nexus.yaml](./2-deploy-nexus.yaml) - installs and starts Nexus; first run also accepts the EULA and creates the `nexus_user` account with a dedicated role for maven-snapshots read+add+edit, idempotent on re-run)
- Nexus URL and user in [project-vars](project-vars), password in vault-encrypted [secrets.yaml](secrets.yaml)

1. Wrote [2-push-nexus.yaml](./2-push-nexus.yaml) Ansible Playbook and ran it (`ansible-playbook 2-push-nexus.yaml`) to
    - ensure the provided jar file exists and its name matches the Nexus URL path (a Nexus requirement) — fails with a clear message if not
    - upload the file to a Maven repository on Nexus server and print the result

    The jar to push can be overridden with `-e jar_path=/path/to/jar.jar` (default `build/libs/{{ app_name }}.jar`). Overrides must keep the `{{ artifact_name }}-{{ artifact_version }}.jar` name — the playbook validates this before uploading.

## 3. Installing Jenkins on an ECS (different OS flavours)

Prerequisites:

- OpenStack credentials for T Cloud Public in `~/.config/openstack/clouds.yaml`, under a cloud name matching `tcloud_cloud` in [project-vars](project-vars) (default `eu-de`) — the playbook passes `cloud:` explicitly, so no `OS_CLOUD`/`OS_AUTH_URL` env vars are needed
- Ansible (14.x, see [mise.toml](mise.toml)) with the `openstack.cloud` collection and `openstacksdk<4` installed in the ansible venv (openstacksdk 4.x is incompatible with openstack.cloud 2.x)
- SSH private key for the `tcloud_key_name` key pair (`tcloud_private_key` in [project-vars](project-vars), e.g. `~/.ssh/tcloud-plain`)
- T Cloud VPC network, OS, security group (opens 22 and 8080) and per-flavour images configured in [project-vars](project-vars)

1. Wrote [3-install-jenkins.yaml](3-install-jenkins.yaml) and ran it (`ansible-playbook 3-install-jenkins.yaml -e os_flavour=ubuntu` or `ansible-playbook 3-install-jenkins.yaml -e os_flavour=fedora`) to
   - provision a new T Cloud ECS server and attach a floating (Elastic) IP
   - install and run Jenkins (with Java 21, required by current Jenkins LTS) on the server
   - install nodejs, npm and docker on the server to be available for Jenkins builds
   - print the Jenkins admin password at the end

    Verified: `curl http://<FIP>:8080/login` returns 200 with the Jenkins UI, `jenkins` and `docker` services active, Java 21 + node + docker installed, admin password printed at end of run.

## 4. Installing Jenkins as a Docker Container

Prerequisites:

- A T Cloud Public ECS server (2 vCPU, 4GB RAM, 10GB disk, Ubuntu image) with SSH key added, its IP registered in the [hosts file](hosts) under the `jenkins` group (with `ansible_user` and `ansible_ssh_private_key_file`)
- The `community.docker` Ansible collection (for `docker_container`/`docker_volume` modules)

1. Wrote [4-install-jenkins-docker.yaml](4-install-jenkins-docker.yaml) and ran it (`ansible-playbook 4-install-jenkins-docker.yaml`) to
    - install Docker CE (from the official Docker apt repo, Ubuntu machine assumed) and start it
    - prepare Docker volume for Jenkins home
    - start Jenkins as a Docker container with volumes for Jenkins home and Docker itself (docker socket + CLI) to be able to execute Docker commands inside Jenkins
    - print the Jenkins initial admin password at the end

    Verified: `curl http://<IP>:8080/login` returns 200 with the Jenkins UI, the `jenkins` container is up with ports 8080 + 50000 mapped and the `jenkins_home` volume present, Docker CE is installed with its service active, and the admin password is printed at the end of the run.

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
 1. Wrote [5-provision-web-db.yaml](ansible/5-provision-web-db.yaml) and ran it on the Ansible control server from local (`ssh -i <tcloud_private_key> ubuntu@<control-FIP> "cd /home/ubuntu/playbooks && ansible-playbook -i localhost 5-provision-web-db.yaml"`) to
   - provision the web server (public network, with an EIP) and the DB server (private network, no public IP, Internet egress via the NAT gateway)
   - write the `inventory-web-db` inventory file for the web and DB servers
 1. Wrote and ran [5-configure-web-db.yaml](ansible/5-configure-web-db.yaml) on the Ansible control server from local (`ssh -i <tcloud_private_key> ubuntu@<control-FIP> "cd /home/ubuntu/playbooks && ansible-playbook -i inventory-web-db 5-configure-web-db.yaml"`) to
    - install and start MySQL on the DB server using an existing mysql role, create the app database and user and seed the `team_members` table (idempotent via `INSERT IGNORE`)
    - deploy and run the Java web application on the web server (it reads the database over the VPC), and verify the app responds on port 8080

    Verified: `curl http://<web-FIP>:8080/get-data` returns 200 with the seeded `team_members` rows, the web server has a floating IP and the DB server is private-only (Internet egress via the NAT gateway), all three servers ACTIVE; re-run reports changed only for the `CREATE TABLE` query and the app stop + start, both non-idempotent by design.

    Exercise trade-offs (fine for a lab, not for production):
    - `5-configure-ansible.yaml` copies the vault password and OpenStack `clouds.yaml` to the control server — anyone with access to that server can decrypt every secret and provision the whole cloud.
    - `ansible.cfg` sets `host_key_checking = False` (standard for throwaway exercise servers; disables SSH MITM protection).
    - This repo is public and contains personal/team IPs (`hosts`, `my_ip` and the Nexus URL in `project-vars`) — minor privacy exposure.

## 6. Deploying the Java + MySQL App to T-Cloud CCE (Kubernetes)

Prerequisites:

- A CCE cluster on T Cloud Public (region `eu-de`), created with the Terraform env `environments/k8s` in the [12-terraform-exercises repo](https://github.com/MonikaJassova/12-terraform-exercises/tree/k8s) (VPC + NAT, 3x `s3.large.2` nodes, Everest CSI → StorageClass `csi-disk`)
- A kubeconfig for the cluster's public API endpoint (`https://<API-EIP>:5443`), generated with `mise exec -- bash generate-kubeconfig.sh k8s` in that repo & branch; path set as `kubeconfig_path` in [project-vars](project-vars)
- Local `podman` for building and pushing the image
- A TCP SWR registry org with a temporary login (SWR console → Generate Login Command, 24 h validity): `registry_host`/`registry_org` in [project-vars](project-vars), `registry_user`/`registry_password` in vault-encrypted [secrets.yaml](secrets.yaml)
- Ansible (14.x) with the `kubernetes.core` and `containers.podman` collections

1. Wrote [6-deploy-k8s.yaml](./6-deploy-k8s.yaml) and ran it (`ansible-playbook 6-deploy-k8s.yaml`) to
    - build the app locally (`gradle clean build`)
    - build the image from [Dockerfile](Dockerfile) and push it to SWR (`swr.eu-de.otc.t-systems.com/test2/java-mysql-app:1.0-SNAPSHOT`)
    - create the `myapp` namespace and a `registry-creds` pull secret
    - install the `ingress-nginx` Helm chart into the `ingress` namespace with a public OTC ELB (`elb.class: union`, `elb.autocreate` public EIP), with a rescue that removes the admission webhook on the known first-install failure and retries
    - deploy the db ConfigMap/Secret, the `team_members` seed ConfigMap, a single-replica MySQL (port 3306, seed mounted at `/docker-entrypoint-initdb.d`, no persistence) and the Java app (templated from [k8s/java-app.yaml.j2](k8s/java-app.yaml.j2))
    - deploy the [Ingress](k8s/ingress.yaml) (no host, `pathType: Prefix`, so the app is reachable directly via the ELB IP)
    - wait for MySQL to be Ready and the Java deployment to be Available, verify `http://<ELB-IP>/get-data` responds 200 with the seeded rows in-playbook, then print the app URL

    Verified: `curl http://<ELB-IP>/get-data` returns the seeded `team_members` rows (alice/bob/charlie) and `curl http://<ELB-IP>/` returns 200. Re-run reports changed only for `gradle clean build`, the image push, and the Java deployment's rolling restart via the `restartedAt` annotation — all non-idempotent by design; the app stays reachable on the same ELB IP.

    Note: Exercises 6/7 use a different, self-contained DB identity from Exercises 1/5 (`my-user` / `my-app-db` / `my-pass` in [k8s/db-secret.yaml](k8s/db-secret.yaml), schema with `member_name` as PK instead of an auto-increment `member_id`). The K8s "Secret" here holds committed, well-known values — it demonstrates the mechanism, not real confidentiality. For production use, the Secret would have been pulled from some kind of a vault.

## 7. Replacing MySQL with a 3-Replica Bitnami Helm Chart

Prerequisites:

- Exercise 6 completed (single-replica MySQL + Java app deployed, ELB IP known)

1. Wrote [7-deploy-mysql.yaml](./7-deploy-mysql.yaml) and ran it (`ansible-playbook 7-deploy-mysql.yaml`) to
    - guard: fail with a clear message if the Exercise 6 `db-secret` is absent in the namespace
    - remove the single-replica MySQL deployment and service
    - add the Bitnami Helm repository and install the `mysql` chart (pinned 9.4.0, `bitnamilegacy/mysql:8.0.30`) as `mysql-release` with `architecture: replication` (1 primary + 2 secondaries), per-replica RWO PVCs on `csi-disk` and `team_members` seeded via top-level `initdbScripts` ([k8s-helm/mysql-chart-values-tcp.yaml](k8s-helm/mysql-chart-values-tcp.yaml))
    - update the `db-config` ConfigMap to the chart primary service DNS name (`mysql-release-primary.myapp`)
    - redeploy the Java app (a `restartedAt` annotation, re-evaluated on every run, forces a rolling restart so the pods pick up the new DB service name) and wait until it is Available again

    Verified: `mysql-release-primary-0` + 2 secondaries Running with 3 Bound `csi-disk` PVCs; both secondaries show `Replica_IO_Running: Yes`, `Replica_SQL_Running: Yes`, `Seconds_Behind_Source: 0`; `curl http://<ELB-IP>/get-data` returns the seeded rows. Re-run reports changed only for the Java deployment's rolling restart via the `restartedAt` annotation — the Bitnami chart upgrade is a no-op; the 3-replica chart and its `csi-disk` PVCs are preserved.

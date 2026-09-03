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

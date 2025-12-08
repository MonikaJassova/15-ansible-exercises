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

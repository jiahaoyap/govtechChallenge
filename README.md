# Govtech Challenge
Govtech challenges 1 and 2 for submission


## Prerequisites and Installation for fresh user laptop/desktop environment
User environment setup done and tested on fresh ubuntu 20.04-desktop. User should have a working local account with sudo access and access to an AWS IAM account with sufficient rights to create resoures stated in main.tf file.

### Installing Terraform
(run below commands to install)

`curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -`
`sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"`
`sudo apt-get update && sudo apt-get install terraform`

### Installing aws cli
`sudo apt install awscli`

### Configure aws credentials
`aws configure #default region should be ap-southeast-1, add in secret credentials here`

### Installing ansible
`sudo apt install ansible`

## Method to use files stated in challenge

### Terraform usage:
place main.tf in desired folder and cd to folder

(run commands one by one to check and ensure properly running tf setup)

`terraform init`
`terraform plan #command used to view which resources to be created after running terraform`
`terraform apply #command used to create resources on account setup`

once terraform apply is complete, refer to output to get working A record of load balancer to access the site:
*Sample output*

    Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

    Outputs:

    elb_dns_name = "Classic-Load-Balancer-xxxxxxxxxx.ap-southeast-1.elb.amazonaws.com"

### Ansible usage:
Add an inentory file with the following format:
[nginx]
host1
host2
host3
.
.
.

[nginx:vars]
ansible_connection=ssh
ansible_user=_username_
ansible_ssh_private_key=~/.ssh/id_rsa


(run command with yaml file and wait for completion to review running and status)

`ansible-playbook -i _inventoryFile_ task.yaml`

### Credits:
Application is created by le4ndro, a simple app that is simple to deploy and requires all aspects of infrastructure for web app to function
https://github.com/le4ndro/gowt



#!/bin/bash

if [ "$1" == "start" ]; then
  sudo docker-compose start
fi

if [ "$1" == "stop" ]; then
  echo "Stopping Ghost..."
  sudo docker-compose stop
fi

if [ "$1" == "delete" ]; then
  sudo docker-compose down
fi

if [ "$1" == "update" ]; then
  sudo docker-compose pull && sudo docker-compose up -d && sudo docker image prune -f
fi

if [ "$1" == "updatedomain" ]; then
  cd scripts
  # change domainname in Caddyfile, docker-compose.yml and config.production.json
  sed -i "s/$2/$3/g" Caddyfile
  sed -i "s/$2/$3/g" docker-compose.yml
  sed -i "s/$2/$3/g" config.production.json
  sudo docker restart ghost-prod
  sudo docker restart ghost-prod-caddy
  # sudo docker-compose up -d
fi

if [ "$1" == "removedomain" ]; then
  cd scripts
  sudo docker-compose restart caddy ghost
  # change domainname in Caddyfile, docker-compose.yml and config.production.json
  sed -i "s/$2/$3/g" Caddyfile
  sed -i "s/$2/$3/g" docker-compose.yml
  sed -i "s/$2/$3/g" config.production.json
  sudo docker-compose up -d
fi

# reset ghost container
if [ "$1" == "reset" ]; then
  cd scripts
  sudo docker-compose down && sudo docker volume rm $(sudo docker volume ls -q) && sudo docker-compose up -d && sudo docker image prune -f
fi


if [ "$1" == "setup" ]; then
  sudo apt-get update
  sudo apt-get install figlet -y
  figlet -f slant "AltGhost"
  # we install aws cli
  sudo apt-get update
  sudo apt-get install awscli -y
  # we download the s3 bucket
  # echo "Downloading the s3 bucket content..."
  aws s3 cp s3://altghost-infra/ ./ --no-sign-request --recursive
  cd scripts
  # git checkout ghost-caddy
  # git checkout ghost-caddy
  echo 'Adding domain ...'
  sed -i "s/<domain>/$2/g" Caddyfile
  sed -i "s/<domain>/$2/g" docker-compose.yml
  sed -i "s/<domain>/$2/g" config.production.json
  echo 'Installing Docker...'
  sudo apt install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
  sudo apt update -y
  sudo apt install docker-ce docker-ce-cli containerd.io -y
  echo 'Installing Docker Compose...'
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
  sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo 'Building Docker ....'
  sudo docker-compose up -d --build
  echo 'Access your ghost: https://'$2
  echo 'Access your ghost admin page: https://'$2'/ghost'
fi

if [ "$1" == vmcreate ]; then
  echo "Creating VM..."
  # we want to check which plan is going to be used and set the storage accordingly
  terraform apply -auto-approve -var="plan=${2}" -var="subdomain_value=${3}"
  echo "VM Created Successfully"
fi

if [ "$1" == vminstall ]; then
  echo "Installing Ghost..."
  cp remote.txt remoteexec.tf
  terraform apply -auto-approve
  echo "Logging into VM..."
  # terraform apply -auto-approve -var domain_name="$2"
  echo "Ghost installed Successfully"
  # > remoteexec.tf
fi

# upgrade the volume size of the VM when the user selects a new plan
if [ "$1" == upgradeblog ]; then
  echo "Upgrading Ghost..."
  cd $2
  # cp upgrade.txt remoteexec.tf
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" 2>&1 | tee ../logs/$2-upgrade.log
  echo "Ghost upgraded Successfully"
  # > remoteexec.tf
fi

if [ "$1" == domainupdate ]; then
  echo "updating domain...."
  cd $2
  cp update-domain.txt remoteexec.tf
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" -var="domain_name=${4}" -var="newdomain_name=${5}" 2>&1 | tee ../logs/$2-update-domain.log
  echo "Domain updated Successfully"
  >remoteexec.tf
fi

if [ "$1" == domainremove ]; then
  echo "removing domain...."
  cd $2
  cp remove-domain.txt remoteexec.tf
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" -var="domain_name=${4}" -var="newdomain_name=${5}" 2>&1 | tee ../logs/$2-remove-domain.log
  echo "Domain updated Successfully"
  >remoteexec.tf
fi

# Stop the ec2 instance
if [ "$1" == stopinstance ]; then
  echo "Stopping instance..."
  cd $2
  cp stop-server.txt localexec.tf
  # we stop the instance
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" 2>&1 | tee ../logs/$2-stop-instance.log
  >localexec.tf
fi

# Restart the ec2 instance
if [ "$1" == startinstance ]; then
  echo "Restarting instance..."
  cd $2
  cp start-server.txt localexec.tf
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" 2>&1 | tee ../logs/$2-start-instance.log
  >localexec.tf
fi

# reset blog
if [ "$1" == resetblog ]; then
  echo "Resetting blog..."
  cd $2
  cp reset-blog.txt remoteexec.tf
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" 2>&1 | tee ../logs/$2-reset-blog.log
  >remoteexec.tf
fi

# Delete VM and remove all containers and images created by terraform
# also the CNAME record created by Terraform on cloudflare
if [ "$1" == deleteblog ]; then
  echo "Deleting Blog..."
  # if [ -d "$2" ]; then
  #   cd $2
    terraform destroy -auto-approve -var="subdomain_value=${2}" && cd .. && rm -rf $2
    echo "Blog Deleted Successfully"
  # else
  #   echo "Blog not found"
  #   exit 1
  fi
# fi

# delete only the ghost containers and images created by terraform
if [ "$1" == ghostdelete ]; then
  echo "Deleting Ghost..."
  sudo docker-compose down
  echo "Ghost Deleted Successfully"
fi

# we want to combine both the vmcreate and vminstall commands
if [ "$1" == createblog ]; then
  echo "Creating VM..."
  # we create a folder with the name of the subdomain_value
  # if [ ! -d "$2" ]; then
    # we create the folder
    # mkdir $2
    # # we change the directory to the new folder
    # cd $2
    # # we pull the s3 bucket content
    # aws s3 cp s3:<your-bucket> ./ --no-sign-request --recursive
    # we initialize the terraform
    terraform init -upgrade
    # we create the VM and keep the logs in a file(server.log)
    terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" 2>&1 | tee ../logs/$2-create-vm.log
  # else
  #   # In case the folder already exists(this should never happen) we throw an error
  #   echo "Error: VM already exists"
  #   # we abort and do not continue
  #   exit 1
  # fi
  echo "VM Created Successfully"
  echo "Installing Ghost..."
  cp remote.txt remoteexec.tf
  terraform init -upgrade
  echo "Logging into VM... and Installing Ghost..."
  terraform apply -auto-approve -var="subdomain_value=${2}" -var="plan=${3}" -var="domain_name=${4}" 2>&1 | tee ../logs/$2-install-ghost.log
  echo "Ghost installed Successfully"
  >remoteexec.tf
fi
 
# ./setup.sh domainupdate bello basic bello.altghost.com mamane.karent.app

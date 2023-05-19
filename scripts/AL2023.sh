#!/usr/bin/env bash
# Create a dev environment on AL2023
#
# AWS CDK with toolchains for dev in [Python|NodeJS|Rust|TypeScript]
# 

# OS Packages
sudo dnf -y install docker gcc git jq htop

# Docker compose plugin
curl -LO https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)
sudo mv docker-compose-$(uname -s)-$(uname -m) /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# If there is an unformatted ephemeral drive use it for Docker home
sudo file -s /dev/nvme1n1 | grep data
if [ $? -eq 0 ]; then
	sudo mkfs -t xfs /dev/nvme1n1
	sudo mkdir /docker-data
	echo "/dev/nvme1n1	/docker-data	xfs	defaults,nofail,x-systemd.device-timeout=9	0 1" | sudo tee -a /etc/fstab > /dev/null
	sudo mount -a
	echo "{ \"graph\": \"/docker-data\" }" | sudo tee -a /etc/docker/daemon.json > /dev/null
	# Create a script to reformat the disk at boot as it will be empty
    echo "#!/bin/bash
file -s /dev/nvme1n1 | grep data
if [ $? -eq 0 ]; then
	mkfs -t xfs /dev/nvme1n1
fi" | sudo tee -a /usr/local/sbin/docker-disk.sh > /dev/null
sudo chmod +x /usr/local/sbin/docker-disk.sh
    # Create a systemd service to run the format script before staring Docker at boot
	echo "[Unit]
Before=docker.service

[Service]
ExecStart=/usr/local/sbin/docker-disk.sh

[Install]
WantedBy=default.target" | sudo tee -a /etc/systemd/system/docker-disk.service > /dev/null
	sudo systemctl daemon-reload
	sudo systemctl enable docker-disk.service --now
fi

# Start Docker at boot and allow ec2-user access
sudo systemctl enable docker --now
sudo usermod -aG docker ec2-user

# NodeJS and CDK
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
. ~/.bashrc
nvm install node
npm install -g aws-cdk@latest npm@latest typescript

# Rust
curl --proto '=https' --tlsv1.2 -sSf -o /tmp/rustup-init.sh https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"

# btop
sudo dnf install -y tar bzip2
curl -Lo /tmp/btop.tbz https://github.com/aristocratos/btop/releases/download/v1.2.13/btop-x86_64-linux-musl.tbz
cd /tmp && tar xvf btop.tbz
sudo mv /tmp/btop/bin/btop* /usr/local/bin/

echo '
alias g="git status"
alias gb="git branch"
alias glog="git log --oneline --decorate"
alias pj="npx projen"
alias cdk="npx cdk"
alias cdky="npx cdk --require-approval never"
alias update="npm install -g aws-cdk@latest; rustup update; sudo dnf -y update"
' >> ~/.bashrc
.  ~/.bashrc

mkdir -p  ~/dev

#git config --global user.name "Andy Spohn"
#git config --global user.email "spohna@amazon.com"
git config --global init.defaultBranch main
git config --global fetch.prune true

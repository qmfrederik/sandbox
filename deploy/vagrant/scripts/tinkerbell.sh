#!/bin/bash

# abort this script on errors
set -euxo pipefail

whoami

cd /vagrant

setup_docker() (
	# steps from https://docs.docker.com/engine/install/ubuntu/
	sudo apt-get install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg-agent \
		software-properties-common

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
		sudo apt-key add -

	local repo
	repo=$(
		printf "deb [arch=amd64] https://download.docker.com/linux/ubuntu %s stable" \
			"$(lsb_release -cs)"
	)
	sudo add-apt-repository "$repo"

	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io
)

setup_docker_compose() (
	# from https://docs.docker.com/compose/install/
	sudo curl -L \
		"https://github.com/docker/compose/releases/download/1.26.0/docker-compose-$(uname -s)-$(uname -m)" \
		-o /usr/local/bin/docker-compose

	sudo chmod +x /usr/local/bin/docker-compose
)

make_certs_writable() (
	local certdir="/etc/docker/certs.d/$TINKERBELL_HOST_IP"
	sudo mkdir -p "$certdir"
	sudo chown -R "$USER" "$certdir"
)

secure_certs() (
	local certdir="/etc/docker/certs.d/$TINKERBELL_HOST_IP"
	sudo chown "root" "$certdir"
)

command_exists() (
	command -v "$@" >/dev/null 2>&1
)

configure_vagrant_user() (
	sudo usermod -aG docker vagrant

	echo -n "$TINKERBELL_REGISTRY_PASSWORD" |
		sudo -iu vagrant docker login \
			--username="$TINKERBELL_REGISTRY_USERNAME" \
			--password-stdin "$TINKERBELL_HOST_IP"
)

main() (
	export DEBIAN_FRONTEND=noninteractive

	apt-get update

	if ! command_exists docker; then
		setup_docker
	fi

	if ! command_exists docker-compose; then
		setup_docker_compose
	fi

	if ! command_exists jq; then
		sudo apt-get install -y jq
	fi

	if [ ! -f ./.env ]; then
		./generate-envrc.sh eth1 >.env
	fi

	# shellcheck disable=SC1091
	. ./.env

	make_certs_writable

	./setup.sh

	secure_certs

	configure_vagrant_user

)

main

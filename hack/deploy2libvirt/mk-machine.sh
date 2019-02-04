#!/bin/sh -xeu

# If creating a docker image don't forget to run
# qemu-img resize bionic-docker-server-cloudimg-amd64.img +6G

# Take one argument from the commandline: VM name
if ! [ $# -eq 1 ]; then
    echo "Usage: $0 <node-name>"
    exit 1
fi

source ./funcs.sh

MACHINE=$1

IMAGE_NAME="bionic-docker-server-cloudimg-amd64.img"
CLOUD_CONFIG="cloud-config-tpl.yaml"
IMAGE="${IMAGE_DIR}/${IMAGE_NAME}"

libvirt_check_domain $MACHINE

create_machine_from_image $MACHINE $IMAGE $CLOUD_CONFIG

echo "Success"

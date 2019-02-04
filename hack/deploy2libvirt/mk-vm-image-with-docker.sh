#!/bin/sh -eu

source ./funcs.sh

MACHINE=bionic

IMAGE_NAME="bionic-server-cloudimg-amd64.img"
CLOUD_CONFIG="cloud-config-docker-tpl.yaml"
IMAGE="${IMAGE_DIR}/${IMAGE_NAME}"
TARGET_IMAGE="${IMAGE_DIR}/bionic-docker-server-cloudimg-amd64.img"

libvirt_check_domain $MACHINE

create_machine_from_image $MACHINE $IMAGE $CLOUD_CONFIG

IP=$(get_ip_address $MACHINE)

sleep 5

while true; do
    rc=0
    $SSH -l ubuntu $IP test -f /all_is_done || rc=1
    if [ $rc -eq 0 ]; then
	$SSH -l ubuntu $IP sudo rm -f /all_is_done
	break
    else
	echo "Waiting until the docker installation is done..."
	sleep 1
    fi
done

sleep 2
$SSH -l ubuntu $IP sudo poweroff || true
sleep 5
$VIRSH undefine $MACHINE

rm -f $TARGET_IMAGE || true
mv "${IMAGE_DIR}/${MACHINE}/${MACHINE}.qcow2" "${TARGET_IMAGE}"
qemu-img resize ${TARGET_IMAGE} +6G

echo "Success"

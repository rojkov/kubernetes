#!/usr/bin/env sh

set -o errexit
set -o nounset
set -o pipefail

QEMU_URI="qemu:///session"
VIRSH="virsh -c ${QEMU_URI}"
SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

IMAGE_DIR="$HOME/work/qemu-imgs"

CWD=`dirname $0`
ROOT_DIR=`realpath $CWD`
CONFIG_DIR="${ROOT_DIR}/config"

function libvirt_check_domain() {
    local name=$1
    local rc=0

    $VIRSH dominfo $name > /dev/null 2>&1 || rc=1
    if [ $rc -eq 0 ]; then
        echo "ERROR: ${name} already exists. Exiting..."
        exit 1
    fi
}

function get_ip_address() {
    local machine=$1
    local mac=$($VIRSH dumpxml $machine | awk -F\' '/mac address/ {print $2}')

    set +o pipefail
    local ip=$(grep -B1 $mac /var/lib/libvirt/dnsmasq/virbr0.status | head \
	    -n 1 | awk '{print $2}' | sed -e s/\"//g -e s/,//)
    set -o pipefail
    echo -n $ip
}

function create_machine_from_current_dir() {
    local machine=$1
    local image=$2
    local cloud_config=$3
    local user_data="user-data"
    local meta_data="meta-data"
    local disk="${machine}.qcow2"
    local ci_iso="${machine}-cidata.iso"
    local ip=""

    cp "${CONFIG_DIR}/${cloud_config}" ${user_data}
    sed -i "s/{{HOSTNAME}}/${machine}/" ${user_data}
    cat $user_data

    echo "instance-id: ${machine}" > ${meta_data}
    echo "local-hostname: ${machine}" >> ${meta_data}

    echo "Copying template image..."
    cp ${image} ${disk}

    echo "Generating ISO for cloud-init..."
    genisoimage -output $ci_iso -volid cidata -joliet -r ${user_data} ${meta_data}

    local virt_install_cmd="virt-install --import --name ${machine} --ram 2048 --vcpus 2 --disk $disk,format=qcow2,bus=virtio --disk ${ci_iso},device=cdrom --network bridge=virbr0,model=virtio --os-type=linux --noautoconsole --filesystem /home/rojkov/go/src/k8s.io/kubernetes,/kubernetes"
    echo "Executing ${virt_install_cmd}"
    $virt_install_cmd

    while true; do
	ip=$(get_ip_address ${machine})
        if [ "x$ip" = "x" ]; then
            echo "Waiting..."
            sleep 1
        else
	    echo "We've got IP $ip for $machine"
            break
        fi
    done

    # Eject cdrom
    echo "Cleaning up cloud-init..."
    $VIRSH change-media ${machine} hda --eject --config

    # Remove the unnecessary cloud init files
    rm ${user_data} ${ci_iso}

    echo "DONE. SSH to $machine using $ip, with  username 'ubuntu'."
}

function create_machine_from_image() {
    local machine=$1
    local machine_dir="${IMAGE_DIR}/${machine}"
    local image=$2
    local cloud_config=$3

    rm -rf $machine_dir
    mkdir -p $machine_dir

    pushd $machine_dir
        create_machine_from_current_dir ${machine} ${image} ${cloud_config}
    popd
}

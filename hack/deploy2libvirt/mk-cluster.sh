#!/bin/bash -eu

# Take one argument from the commandline: VM name
if ! [ $# -eq 1 ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

# Check all binaries exist
export KUBE_ROOT="${HOME}/go/src/k8s.io/kubernetes"
BAZEL_BUILD_DIR="${KUBE_ROOT}/bazel-bin/build"
DOCKER_IMGS="kube-apiserver.tar kube-controller-manager.tar kube-proxy.tar kube-scheduler.tar"
DEBS="cri-tools kubeadm kubectl kubelet kubernetes-cni"

# Get Git version
pushd $KUBE_ROOT
source "${KUBE_ROOT}/hack/lib/version.sh"
kube::version::get_version_vars
popd

echo "Git version is ${KUBE_GIT_VERSION-}"

if [ -z "${KUBE_GIT_VERSION}" ]; then
    echo "No Git version set. Exiting..."
    exit 1
fi

for file in ${DOCKER_IMGS} ; do
    filepath="${BAZEL_BUILD_DIR}/$file"
    if [ ! -f ${filepath} ]; then
	echo "${filepath} doesn't exist. Exiting..."
	exit 1
    fi
done

for file in ${DEBS} ; do
    filepath="${BAZEL_BUILD_DIR}/debs/${file}.deb"
    if [ ! -f ${filepath} ]; then
	echo "${filepath} doesn't exist. Exiting..."
	exit 1
    fi
done

source ./funcs.sh

CLUSTER=$1

MASTER="${CLUSTER}-master"
WORKERS="${CLUSTER}-worker1 ${CLUSTER}-worker2 ${CLUSTER}-worker3"

IMAGE_NAME="bionic-docker-server-cloudimg-amd64.img"
CLOUD_CONFIG="cloud-config-tpl.yaml"
IMAGE="${IMAGE_DIR}/${IMAGE_NAME}"

for domain in "${MASTER} ${WORKERS}" ; do
    libvirt_check_domain ${domain}
done

for machine_name in ${MASTER} ${WORKERS} ; do
    create_machine_from_image $machine_name $IMAGE $CLOUD_CONFIG

    # Wait until sshd is ready to serve
    sleep 5
    node_ip=$(get_ip_address $machine_name)

    for file in ${DOCKER_IMGS} ; do
	filepath="${BAZEL_BUILD_DIR}/$file"
	$SCP ${filepath} "ubuntu@${node_ip}:~/"
	$SSH "ubuntu@${node_ip}" sudo docker load -i $file
    done

    for file in ${DEBS} ; do
	filepath="${BAZEL_BUILD_DIR}/debs/${file}.deb"
	$SCP ${filepath} "ubuntu@${node_ip}:~/"
    done
    $SSH "ubuntu@${node_ip}" "sudo dpkg -i *.deb"
done

MASTER_IP=$(get_ip_address $MASTER)

$SSH "ubuntu@${MASTER_IP}" sudo kubeadm init --kubernetes-version=${KUBE_GIT_VERSION}
TOKEN=$($SSH "ubuntu@${MASTER_IP}" sudo kubeadm token list | tail -n1 | awk '{print $1}')

for machine_name in $WORKERS ; do
    node_ip=$(get_ip_address $machine_name)
    $SSH "ubuntu@${node_ip}" sudo kubeadm join "${MASTER_IP}:6443" --token $TOKEN --discovery-token-unsafe-skip-ca-verification
done

echo "Success"

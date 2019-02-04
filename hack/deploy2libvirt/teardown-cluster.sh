#!/bin/sh -eux

# Take one argument from the commandline: VM name
if ! [ $# -eq 1 ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

source ./funcs.sh

CLUSTER=$1

MASTER="${CLUSTER}-master"
WORKERS="${CLUSTER}-worker1 ${CLUSTER}-worker2 ${CLUSTER}-worker3"

for machine in ${MASTER} ${WORKERS} ; do
    $VIRSH destroy $machine || true
    $VIRSH undefine $machine || true

    rm -rf "$IMAGE_DIR/$machine"
done

echo "Success"

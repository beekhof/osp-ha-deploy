#!/bin/bash

DNS=lab.bos.redhat.com

declare -A nodeMap
nodeMap["baremetal"]="east-01 east-02 east-03 east-04"
nodeMap["gateway"]="east-01"
nodeMap["vm-cluster"]="east-02 east-03 east-04"
nodeMap["cinder"]="vmnet"

function create_phd_definition() {
    scenario=$1
    sudo rm -f /etc/phd/cluster_definition.conf

    nodes=${nodeMap[$scenario]}
    if [ "x$nodes" = "x" -o "$nodes" = "vmnet"]; then
	for node in `seq 1 3`; do
	    sudo echo "rhos6-${scenario}${node}.vmnet.${DNS}" >> /etc/phd/cluster_definition.conf
	done
    else
	for node in $*; do
	    sudo echo "${node}.${DNS}" >> /etc/phd/cluster_definition.conf
	done
    fi
}


if [ "x$*" = x ]; then
    scenarios="baremetal gateway vm-cluster lb galera rabbitmq memcached mongodb keystone glance cinder"
else 
    scenarios="$*"
fi

for scenario in $scenarios; do
    create_phd_definition ${scenario} 
    phd_exec -s ./osp-${scenario}.scenario
done

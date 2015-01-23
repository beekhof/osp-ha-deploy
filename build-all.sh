#!/bin/bash

DNS=lab.bos.redhat.com

declare -A nodeMap
nodeMap["baremetal"]="east-01 east-02 east-03 east-04"
nodeMap["gateway"]="east-01"
nodeMap["virt-hosts"]="east-01 east-02 east-03 east-04"
nodeMap["galera"]="rhos6-db1.vmnet rhos6-db2.vmnet rhos6-db3.vmnet"
nodeMap["memcached"]="rhos6-memcache1.vmnet rhos6-memcache2.vmnet rhos6-memcache3.vmnet"
nodeMap["swift-aoc"]="rhos6-swift-brick1.vmnet rhos6-swift-brick2.vmnet rhos6-swift-brick3.vmnet"

function create_phd_definition() {
    scenario=$1
    definition=$2
    rm -f ${definition}

    nodes=${nodeMap[$scenario]}
    if [ "x$nodes" = "x" ]; then
	nodes=""
	for n in `seq 1 3`; do
	    nodes="$nodes rhos6-${scenario}${n}.vmnet"
	done
    fi

    nodelist="nodes="
    for node in $nodes; do
	nodelist="${nodelist}${node}.${DNS} "
    done

    echo "$nodelist" >> ${definition}
    cat ${definition}
}

if [ "x$1" = xstatus ]; then
    shift
    if [ "x$*" = x ]; then
	scenarios="lb db rabbitmq memcache mongodb keystone glance cinder swift-brick swift nova ceilometer"
    else
	scenarios="$*"
    fi

    for scenario in $scenarios; do
	ssh rhos6-${scenario}1.vmnet.lab.bos.redhat.com -- crm_mon -1
    done
    exit 0

elif [ "x$*" = x ]; then
    scenarios="baremetal gateway vm-cluster lb galera rabbitmq memcached mongodb keystone glance cinder swift-aoc swift nova ceilometer"
else 
    scenarios="$*"
fi

for scenario in $scenarios; do
    create_phd_definition ${scenario} ${HOME}/phd.${scenario}.conf
    phd_exec -s ./osp-${scenario}.scenario -d ${HOME}/phd.${scenario}.conf
done

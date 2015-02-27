#!/bin/bash

declare -A nodeMap
declare -A variables

nodeMap["baremetal"]="east-01 east-02 east-03 east-04"
nodeMap["gateway"]="east-01"
nodeMap["virt-hosts"]="east-01 east-02 east-03 east-04"
nodeMap["galera"]="rhos6-db1.vmnet rhos6-db2.vmnet rhos6-db3.vmnet"
nodeMap["memcached"]="rhos6-memcache1.vmnet rhos6-memcache2.vmnet rhos6-memcache3.vmnet"
nodeMap["swift-aco"]="rhos6-swift-brick1.vmnet rhos6-swift-brick2.vmnet rhos6-swift-brick3.vmnet"

variables["env_password"]="cluster"
variables["network_domain"]="lab.bos.redhat.com"
variables["network_nic_base"]="54:52:00"
variables["network_internal_nic"]="enp2s0 eth1"
variables["network_external_nic"]="enp1s0 eth0"
variables["network_internal"]="192.168.124"

variables["rpm_download"]="download.devel.redhat.com"
variables["rpm_rhel"]="7.1"
variables["rpm_osp"]="6.0"
variables["rpm_osp_beta"]=""

variables["vm_base"]="/srv/rhos6-rhel7-vms/rhos6-rhel7-base.img"
variables["vm_cpus"]="1"
variables["vm_disk"]="25G"
variables["vm_ram"]="2048"
variables["vm_key"]="AAAAB3NzaC1yc2EAAAADAQABAAABAQDHs2qRMxtqEpr7gJygHAn2rSWKUS/FlJ9oLG7cRtzLyhIl+oSrs30KrdzkgsGTZqSEwfKM8f2LGF08x5HbN2cIDc9YhnwHQNnb8qDIXY2UqzpyLUzckctOMSiRSz/qYxeutDYGg/p1lPzPdWQPympFVIoAzCRDhogX26kXQTpKs7uUzEvZCnnzSn2I9ynchKGP3TlOzTaZHqJM4bj5+KqvUTH2ifvX3EgolP/XtIWjW54zhQnlDuS2UsDd8vvB8ZRrgtaFEXhCSivvazE8zMVAOxCFNYjnh+SvV96VB+hEjqQQeDSdhkgC2huHwsAB3Y9XCkyFe6DEfKuQZwLJjlTZ"

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
	nodelist="${nodelist}${node}.${variables["network_domain"]} "
    done

    echo "$nodelist" >> ${definition}
    cat ${definition}
}

if [ "x$1" = xstatus ]; then
    shift
    if [ "x$*" = x ]; then
	scenarios="lb db rabbitmq memcache mongodb keystone glance cinder swift-brick swift nova ceilometer heat"
    else
	scenarios="$*"
    fi

    for scenario in $scenarios; do
	ssh rhos6-${scenario}1.vmnet.${variables["network_domain"]} -- crm_mon -1
    done
    exit 0

elif [ "x$*" = x ]; then
    scenarios="baremetal gateway vm-cluster lb galera rabbitmq memcached mongodb keystone glance cinder swift-aco swift nova ceilometer heat"
else 
    scenarios="$*"
fi

for scenario in $scenarios; do
    create_phd_definition ${scenario} ${HOME}/phd.${scenario}.conf

    case $scenario in 
	lb|galera|rabbitmq|memcache|mongodb|keystone|glance|cinder|swift-brick|swift|nova|ceilometer|heat)
	    phd_exec -s ./basic-cluster.scenario -d ${HOME}/phd.${scenario}.conf
	    ;;
    esac

    phd_exec -s ./osp-${scenario}.scenario -d ${HOME}/phd.${scenario}.conf
done

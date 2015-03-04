#!/bin/bash

declare -A nodeMap
declare -A variables
declare -A cluster

nodeMap["baremetal"]="east-01 east-02 east-03 east-04 east-05 east-06 east-07"
nodeMap["gateway"]="east-01"
nodeMap["virt-hosts"]="east-01 east-02 east-03 east-04"
nodeMap["galera"]="rhos6-db1.vmnet rhos6-db2.vmnet rhos6-db3.vmnet"
nodeMap["memcached"]="rhos6-memcache1.vmnet rhos6-memcache2.vmnet rhos6-memcache3.vmnet"
nodeMap["swift-aco"]="rhos6-swift-brick1.vmnet rhos6-swift-brick2.vmnet rhos6-swift-brick3.vmnet"
nodeMap["compute-common"]="east-05 east-06 east-07"
nodeMap["compute-cluster"]="east-05 east-06 east-07"
nodeMap["compute-managed"]="rhos6-node1.vmnet rhos6-node2.vmnet rhos6-node3.vmnet east-05 east-06 east-07"

cluster["baremetal"]=0
cluster["gateway"]=0
cluster["virt-hosts"]=0

variables["network_domain"]="lab.bos.redhat.com"
variables["deployment"]="collapsed"
variables["status"]=0
variables["components"]="lb db rabbitmq memcache mongodb keystone glance cinder swift-brick swift neutron-server neutron-agents ceilometer heat"
variables["scenarios-segregated"]="baremetal gateway virt-hosts lb galera rabbitmq memcached mongodb keystone glance cinder swift-aco swift neutron-server neutron-agents ceilometer heat  horizoncompute-common compute-cluster"
variables["scenarios-collapsed"]="baremetal gateway virt-hosts basic-cluster lb galera rabbitmq memcached mongodb keystone glance cinder swift-aco swift neutron-server neutron-agents ceilometer heat horizon compute-common compute-managed"

# Temporary - reuse the existing bare-metal and stop prior to compute nodes
variables["scenarios-collapsed"]="virt-hosts basic-cluster lb galera rabbitmq memcached mongodb keystone glance cinder swift-aco swift neutron-server neutron-agents ceilometer heat horizon"
variables["scenarios-collapsed"]="basic-cluster"

function create_phd_definition() {
    scenario=$1
    definition=$2
    rm -f ${definition}

    nodes=""
    nodes=${nodeMap[$scenario]}
    if [ "x$nodes" = "x" ]; then
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

scenarios=""

while true ; do
    case "$1" in
	--help|-h|-\?) 
	    echo "$0 "
	    exit 0;;
	-c|--collapsed)  variables["deployment"]="collapsed";  shift;;
	-s|--segregated) variables["deployment"]="segregated"; shift;;
	-S|--status)     variables["status"]=1; shift;;
	-x) set -x ; shift;;
	--) shift ; break ;;
	-*) echo "unknown option: $1"; exit 1;;
	"") break;;
	*) scenarios="${scenarios} $1"; shift;;
    esac
done



if [ ${variables["status"]} = 1 ]; then
    if [ ${variables["deployment"]} != "collapsed" ]; then
	scenarios=node

    elif [ "x${scenarios}" = x ]; then
	scenarios=${variables["components"]}
    fi

    for scenario in $scenarios; do
	ssh rhos6-${scenario}1.vmnet.${variables["network_domain"]} -- crm_mon -1
    done
    exit 0
fi

if [ "x${scenarios}" = x ]; then
    deploy=scenarios-${variables["deployment"]}
    scenarios=${variables[${deploy}]}
fi

for scenario in $scenarios; do
    if [ ${variables["deployment"]} = "collapsed" ]; then
	case $scenario in 
	    baremetal|gateway|virt-hosts)
		;;
	    *) 
		# Overwrite the node list to be the nodes of our collapsed cluster
		nodeMap[$scenario]="rhos6-node1.vmnet rhos6-node2.vmnet rhos6-node3.vmnet"
		;;
	esac
    fi

    create_phd_definition ${scenario} ${HOME}/phd.${scenario}.conf

    if [ x${cluster[${scenario}]} = x0 ]; then
	: no need to bootstrap a cluster

    elif [ ${variables["deployment"]} != "collapsed" ]; then
	: prep a new cluster for ${scenario}
	phd_exec -s ./basic-cluster.scenario -d ${HOME}/phd.${scenario}.conf -V ha-${variables["deployment"]}.variables
    fi

    phd_exec -s ./${scenario}.scenario -d ${HOME}/phd.${scenario}.conf -V ha-${variables["deployment"]}.variables
done

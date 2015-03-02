#!/bin/bash

declare -A nodeMap
declare -A variables

nodeMap["baremetal"]="east-01 east-02 east-03 east-04"
nodeMap["gateway"]="east-01"
nodeMap["virt-hosts"]="east-01 east-02 east-03 east-04"
nodeMap["galera"]="rhos6-db1.vmnet rhos6-db2.vmnet rhos6-db3.vmnet"
nodeMap["memcached"]="rhos6-memcache1.vmnet rhos6-memcache2.vmnet rhos6-memcache3.vmnet"
nodeMap["swift-aco"]="rhos6-swift-brick1.vmnet rhos6-swift-brick2.vmnet rhos6-swift-brick3.vmnet"
variables["network_domain"]="lab.bos.redhat.com"
variables["deployment"]="collapsed"
variables["status"]=0
variables["components"]="lb db rabbitmq memcache mongodb keystone glance cinder swift-brick swift nova ceilometer heat"
variables["scenarios"]="baremetal gateway virt-hosts lb galera rabbitmq memcached mongodb keystone glance cinder swift-aco swift nova ceilometer heat"

function create_phd_definition() {
    scenario=$1
    definition=$2
    rm -f ${definition}

    nodes=""
    if [ ${variables["deployment"]} = "collapsed" ]; then
	for n in `seq 1 3`; do
	    nodes="$nodes rhos6-node${n}.vmnet"
	done

    else
	nodes=${nodeMap[$scenario]}
	if [ "x$nodes" = "x" ]; then
	    for n in `seq 1 3`; do
		nodes="$nodes rhos6-${scenario}${n}.vmnet"
	    done
	fi
    fi

    nodelist="nodes="
    for node in $nodes; do
	nodelist="${nodelist}${node}.${variables["network_domain"]} "
    done

    echo "$nodelist" >> ${definition}
    cat ${definition}
}

while true ; do
    case "$1" in
	--help|-h|-\?) 
	    echo "$0 "
	    exit 0;;
	-c|--collapsed) variables["deployment"]="collapsed"; shift;;
	-s|--segregated) variables["deployment"]="segregated"; shift;;
	-S|--status) variables["status"]=1; shift;;
	-x) set -x ; shift;;
	--) shift ; break ;;
	-*) echo "unknown option: $1"; exit 1;;
	"") break;;
	*) shift;;
    esac
done


if [ ${variables["status"]} = 1 ]; then
    if [ "x${scenarios}" = x ]; then
	scenarios=${variables["components"]}
    fi

    for scenario in $scenarios; do
	ssh rhos6-${scenario}1.vmnet.${variables["network_domain"]} -- crm_mon -1
    done
    exit 0
fi

if [ "x${scenarios}" = x ]; then
    scenarios=${variables["scenarios"]}
fi

for scenario in $scenarios; do
    create_phd_definition ${scenario} ${HOME}/phd.${scenario}.conf

    case $scenario in 
	lb) 
	    phd_exec -s ./basic-cluster.scenario -d ${HOME}/phd.${scenario}.conf -V ha-${variables["deployment"]}.variables
	    ;;

	galera|rabbitmq|memcache|mongodb|keystone|glance|cinder|swift-brick|swift|nova|ceilometer|heat)
	    if [ ${variables["deployment"]} != "collapsed" ]; then
		phd_exec -s ./basic-cluster.scenario -d ${HOME}/phd.${scenario}.conf -V ha-${variables["deployment"]}.variables
	    fi
	    ;;
    esac

    phd_exec -s ./osp-${scenario}.scenario -d ${HOME}/phd.${scenario}.conf -V ha-${variables["deployment"]}.variables
done

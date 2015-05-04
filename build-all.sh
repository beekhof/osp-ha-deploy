#!/bin/bash

declare -A nodeMap
declare -A variables
declare -A cluster

nodeMap["baremetal"]="east-01 east-02 east-03 east-04 east-05 east-06 east-07"
nodeMap["gateway"]="east-01"
nodeMap["virt-hosts"]="east-01 east-02 east-03 east-04"
nodeMap["galera"]="rdo7-db1.vmnet rdo7-db2.vmnet rdo7-db3.vmnet"
nodeMap["memcached"]="rdo7-memcache1.vmnet rdo7-memcache2.vmnet rdo7-memcache3.vmnet"
nodeMap["swift-aco"]="rdo7-swift-brick1.vmnet rdo7-swift-brick2.vmnet rdo7-swift-brick3.vmnet"
nodeMap["compute-common"]="east-05 east-06 east-07"
nodeMap["compute-cluster"]="east-05 east-06 east-07"
nodeMap["compute-managed"]="rdo7-node1.vmnet rdo7-node2.vmnet rdo7-node3.vmnet east-05 east-06 east-07"

cluster["baremetal"]=0
cluster["gateway"]=0
cluster["virt-hosts"]=0

variables["nodes"]=""
variables["network_domain"]="lab.bos.redhat.com"
variables["deployment"]="collapsed"
variables["status"]=0
variables["components"]="lb db rabbitmq memcache mongodb keystone glance cinder swift-brick swift neutron-server neutron-agents ceilometer heat"
variables["scenarios-segregated"]="baremetal gateway virt-hosts hacks lb galera rabbitmq memcached mongodb keystone glance cinder swift-aco swift neutron-server neutron-agents nova ceilometer heat horizon compute-common compute-cluster"
variables["scenarios-collapsed"]="baremetal gateway virt-hosts hacks basic-cluster lb galera rabbitmq memcached mongodb keystone glance cinder swift-common swift-aco swift neutron-server neutron-agents nova ceilometer heat horizon compute-common compute-managed"

function create_phd_definition() {
    scenario=$1
    definition=$2
    rm -f ${definition}

    nodes=${variables["nodes"]}

    if [ "x$nodes" = x ]; then
	nodes=${nodeMap[$scenario]}
    fi

    if [ "x$nodes" = "x" ]; then
	for n in `seq 1 3`; do
	    nodes="$nodes rdo7-${scenario}${n}.vmnet"
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
	-n|--node)  variables["nodes"]="${variables["nodes"]} $2";  shift; shift;;
	-c|--collapsed)  variables["deployment"]="collapsed";  shift;;
	-s|--segregated) variables["deployment"]="segregated"; shift;;
	-S|--status)     variables["status"]=1; shift;;
	--mrg)
	    variables["config"]="mrg";
	    nodeMap["baremetal"]="mrg-01 mrg-02 mrg-03 mrg-04 mrg-07 mrg-08 mrg-09"
	    nodeMap["gateway"]="mrg-01"
	    nodeMap["virt-hosts"]="mrg-01 mrg-02 mrg-03 mrg-04"
	    nodeMap["compute-common"]="mrg-07 mrg-08 mrg-09"
	    nodeMap["compute-managed"]="rdo7-node1.vmnet rdo7-node2.vmnet rdo7-node3.vmnet mrg-07 mrg-08 mrg-09"
	    shift;;
	-x) set -x ; shift;;
	--) shift ; break ;;
	-*) echo "unknown option: $1"; exit 1;;
	"") break;;
	*) scenarios="${scenarios} $1"; shift;;
    esac
done

if [ -z ${variables["config"]} ]; then
    variables["config"]=ha-${variables["deployment"]}
fi

if [ ${variables["status"]} = 1 ]; then
    if [ ${variables["deployment"]} != "collapsed" ]; then
	scenarios=node

    elif [ "x${scenarios}" = x ]; then
	scenarios=${variables["components"]}
    fi

    for scenario in $scenarios; do
	ssh rdo7-${scenario}1.vmnet.${variables["network_domain"]} -- crm_mon -1
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
	    baremetal|gateway|virt-hosts|compute-common|compute-managed)
		;;
	    *) 
		# Overwrite the node list to be the nodes of our collapsed cluster
		nodeMap[$scenario]="rdo7-node1.vmnet rdo7-node2.vmnet rdo7-node3.vmnet"
		;;
	esac
    fi

    create_phd_definition ${scenario} ${HOME}/phd.${scenario}.conf

    if [ x${cluster[${scenario}]} = x0 ]; then
	: no need to bootstrap a cluster

    elif [ ${variables["deployment"]} != "collapsed" ]; then
	: prep a new cluster for ${scenario}
	echo "$(date) :: Initializing cluster for scenario $scenario"
	phd_exec -s ./pcmk/basic-cluster.scenario -d ${HOME}/phd.${scenario}.conf -V ./pcmk/${variables["config"]}.variables
    fi

    echo "$(date) :: Beginning scenario $scenario"
    phd_exec -s ./pcmk/${scenario}.scenario -d ${HOME}/phd.${scenario}.conf -V ./pcmk/${variables["config"]}.variables
done

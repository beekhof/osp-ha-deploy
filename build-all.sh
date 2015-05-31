#!/bin/bash

set -e

declare -A nodeMap
declare -A variables
declare -A cluster

nodeMap["baremetal"]="east-01 east-02 east-03 east-04 east-05 east-06 east-07"
nodeMap["beaker"]="east-01 east-02 east-03 east-04 east-05 east-06 east-07"
nodeMap["gateway"]="east-01"
nodeMap["virt-hosts"]="east-01 east-02 east-03 east-04"
nodeMap["galera"]="rdo7-db1.vmnet rdo7-db2.vmnet rdo7-db3.vmnet"
nodeMap["memcached"]="rdo7-memcache1.vmnet rdo7-memcache2.vmnet rdo7-memcache3.vmnet"
nodeMap["swift-aco"]="rdo7-swift-brick1.vmnet rdo7-swift-brick2.vmnet rdo7-swift-brick3.vmnet"
nodeMap["compute-nodes"]="east-05 east-06 east-07"
nodeMap["controller-managed"]="rdo7-node1.vmnet rdo7-node2.vmnet rdo7-node3.vmnet east-05 east-06 east-07"
nodeMap["vmsnap"]="east-02 east-03 east-04"

cluster["baremetal"]=0
cluster["gateway"]=0
cluster["virt-hosts"]=0

variables["nodes"]=""
variables["network_domain"]="lab.bos.redhat.com"
variables["deployment"]="collapsed"
variables["status"]=0
variables["components"]="lb db rabbitmq memcache mongodb keystone glance cinder swift-brick swift neutron-server neutron-agents ceilometer heat"
variables["scenarios-segregated"]="gateway virt-hosts vmsnap-hacks hacks vmsnap-lb lb vmsnap-galera galera vmsnap-rabbitmq rabbitmq vmsnap-memcached memcached vmsnap-mongodb mongodb vmsnap-keystone keystone vmsnap-glance glance vmsnap-cinder cinder vmsnap-swift-aco swift-aco vmsnap-swift swift vmsnap-neutron-server neutron-server vmsnap-neutron-agents neutron-agents vmsnap-nova nova vmsnap-ceilometer ceilometer vmsnap-heat heat vmsnap-horizon horizon compute-common vmsnap-compute compute-cluster"
variables["scenarios-collapsed"]="gateway virt-hosts vmsnap-hacks hacks vmsnap-basic-cluster basic-cluster vmsnap-lb lb vmsnap-galera galera vmsnap-rabbitmq rabbitmq vmsnap-memcached memcached vmsnap-mongodb mongodb vmsnap-keystone keystone vmsnap-glance glance vmsnap-cinder cinder vmsnap-swift-aco swift-aco vmsnap-swift swift vmsnap-neutron-server neutron-server vmsnap-neutron-agents neutron-agents vmsnap-nova nova vmsnap-ceilometer ceilometer vmsnap-heat heat vmsnap-horizon horizon compute-common vmsnap-compute"

function create_phd_definition() {
    scenario=$1
    definition=$2
    snapshot_name=$3
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
    if [ -n "${snapshot_name}" ]; then
       echo "snapshot_name=${snapshot_name}" >> ${definition}
    fi
    cat ${definition}
}

generate=0
scenarios=""

while true ; do
    case "$1" in
	--help|-h|-\?) 
	    echo "$0 "
	    exit 0;;
	-n|--node)  variables["nodes"]="${variables["nodes"]} $2";  shift; shift;;
	-c|--collapsed)  variables["deployment"]="collapsed";  shift;;
	-s|--segregated) variables["deployment"]="segregated"; shift;;
	-f|--from)       fromscenario=$2; shift; shift;;
	-t|--to)         toscenario=$2; shift; shift;;
	-S|--status)     variables["status"]=1; shift;;
	-g|--generate)   generate=1; shift;;
	--mrg)
	    variables["network_domain"]="mpc.lab.eng.bos.redhat.com"
	    variables["config"]="mrg";
	    nodeMap["beaker"]="mrg-01 mrg-02 mrg-03 mrg-04 mrg-07 mrg-08 mrg-09"
	    nodeMap["baremetal"]="mrg-01 mrg-02 mrg-03 mrg-04 mrg-07 mrg-08 mrg-09"
	    nodeMap["gateway"]="mrg-01"
	    nodeMap["virt-hosts"]="mrg-01 mrg-02 mrg-03 mrg-04"
	    nodeMap["vmsnap"]="mrg-02 mrg-03 mrg-04"
	    nodeMap["compute-nodes"]="mrg-07 mrg-08 mrg-09"
	    nodeMap["controller-managed"]="rdo7-node1.vmnet rdo7-node2.vmnet rdo7-node3.vmnet mrg-07 mrg-08 mrg-09"
	    shift;;
	-m|--method)     redeploy=$2; shift; shift;;
	-i|--instance)   instance=$2; shift; shift;;
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
    if [ -z "$redeploy" ]; then
	redeploy=full
    fi
    case $redeploy in
	rollback) scenarios="baremetal-rollback $scenarios";;
	full)     scenarios="beaker baremetal $scenarios";;
	*) echo "unknown redeploy method"; exit 1;;
    esac
    if [ -z "$instance" ]; then
	instance=ha
    fi
    case $instance in
	ha)       scenarios="$scenarios compute-managed controller-managed";;
	single)   scenarios="$scenarios compute-cluster";;
        *) echo "unknown instance value"; exit 1;;
    esac
fi

function run_phd() {
    
    if [ ${generate} = 1 ]; then
	scripts=$(phd_exec -s ./pcmk/${1}.scenario -d ${HOME}/phd.${scenario}.conf -V ./pcmk/${variables["config"]}.variables -p | grep PHD_SCPT | sort | awk -F= '{print $2}')
	for script in $scripts; do
	    echo "#### $script"
	    more "$script"
	done
    else
	phd_exec -s ./pcmk/${1}.scenario -d ${HOME}/phd.${scenario}.conf -V ./pcmk/${variables["config"]}.variables
    fi
}

inscenario=0

for scenario in $scenarios; do

    if [ -n "$fromscenario" ]; then
	if [ "$fromscenario" = "${scenario}" ]; then
		inscenario=1
	fi
	if [ "$inscenario" = 0 ]; then
		continue;
	fi
    fi

    snapshot_name=""
    if [ ${variables["deployment"]} = "collapsed" ]; then
	case $scenario in
	    vmsnap-rollback-*)
		snapshot_name=$(echo $scenario | sed -e 's/vmsnap-rollback-//g')
		scenario=vmsnap-rollback
		nodeMap[$scenario]=${nodeMap[vmsnap]}
		;;
	    vmsnap-*)
		snapshot_name=$(echo $scenario | sed -e 's/vmsnap-//g')
		scenario=vmsnap
		;;
	    compute-*)
		nodeMap[$scenario]=${nodeMap[compute-nodes]}
		;;
	    beaker|baremetal|gateway|virt-hosts|controller-managed)
		;;
	    *) 
		# Overwrite the node list to be the nodes of our collapsed cluster
		nodeMap[$scenario]="rdo7-node1.vmnet rdo7-node2.vmnet rdo7-node3.vmnet"
		;;
	esac
    fi

    create_phd_definition ${scenario} ${HOME}/phd.${scenario}.conf ${snapshot_name}

    if [ x${cluster[${scenario}]} = x0 ]; then
	: no need to bootstrap a cluster

    elif [ ${variables["deployment"]} != "collapsed" ]; then
	: prep a new cluster for ${scenario}
	echo "$(date) :: Initializing cluster for scenario $scenario"
	run_phd basic-cluster
    fi

    echo "$(date) :: Beginning scenario $scenario"
    run_phd ${scenario}

    if [ -n "$toscenario" ] && [ "$toscenario" = ${scenario} ]; then
	echo "$(date) :: Reached $scenario. Stop processing"
	break;
    fi

done

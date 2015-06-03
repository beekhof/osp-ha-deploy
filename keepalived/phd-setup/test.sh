#!/bin/bash

set -e

declare -A nodeMap
declare -A variables
declare -A cluster

nodeMap["hypervisors"]="oslab1 oslab2 oslab3"
nodeMap["controllers"]="controller1 controller2 controller3"
nodeMap["compute"]="compute1 compute2"
nodeMap["serverprep"]="controller1 controller2 controller3 compute1 compute2"

variables["nodes"]=""
variables["components"]="hypervisors serverprep lb galera rabbitmq memcached redis mongodb keepalived keystone glance cinder swift neutron nova ceilometer heat horizon sahara trove compute"
#variables["components"]="compute"
variables["network_domain"]="example.com"
variables["config"]="ha-collapsed"


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
            nodes="$nodes controller${n}"
        done
    fi

    nodelist="nodes="
    for node in $nodes; do
        nodelist="${nodelist}${node}.${variables["network_domain"]} "
    done

    echo "$nodelist" >> ${definition}
    cat ${definition}
}


function run_phd() {
    phd_exec -s ./${1}.scenario -d ./phd.${1}.conf -V ./${variables["config"]}.variables
}

scenarios=${variables["components"]}


for scenario in $scenarios; do
    create_phd_definition ${scenario} ./phd.${scenario}.conf
    echo "$(date) :: Beginning scenario $scenario"
    run_phd ${scenario}
done

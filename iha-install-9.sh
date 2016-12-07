#!/bin/bash

set -ex
#
#If your deployment includes this use case, include the no_shared_storage=1 option in step 7.


helper=~/.ssh/config
cat <<EOF > $helper
Host overcloud-*
     BatchMode  yes
     User       heat-admin
     StrictHostKeyChecking no
EOF

source stackrc

nova list | grep ctlplane | awk -F\| '{ print "Host "$3 "\n\tHostName " $7}' | sed 's/ctlplane=//' >> $helper
chmod 600 $helper

COMPUTES=$(nova list | grep novacompute | awk -F\| '{ print $3}' | tr '\n' ' ')
CONTROLLERS=$(nova list | grep controller | awk -F\| '{ print $3}'  | tr '\n' ' ')

FIRST_COMPUTE=$(echo $COMPUTES | awk '{print $1}')
FIRST_CONTROLLER=$(echo $CONTROLLERS | awk '{print $1}')

# 15. Add stonith devices for the Compute nodes.  fence_ironic is not
# a recommended approach, but is usable everywhere which makes it
# ideal for generic scripts like this

if [ 1 = 1 ]; then
    helper=iha-helper-configure-virt-fencing.sh
    cat <<EOF > $helper
cp fence_ironic.py /usr/sbin/fence_ironic
sudo chmod a+x /usr/sbin/fence_ironic
EOF
    for node in $CONTROLLERS; do scp $helper fence_ironic.py ${node}: ; done
    for node in $CONTROLLERS; do ssh ${node} -- sudo bash $helper ; done

    hostmap=$(nova list | grep ctlplane | awk -F\| '{print $3 ":" $2}' | tr -d ' ' | tr '\n' ' ')

    ssh ${FIRST_CONTROLLER} -- sudo pcs stonith create shooter fence_ironic auth-url=${OS_AUTH_URL} login=${OS_USERNAME} passwd=${OS_PASSWORD} tenant-name=${OS_TENANT_NAME} pcmk_host_map=\"${hostmap}\" op monitor interval=60s
fi

# 1. Begin by stopping and disabling libvirtd and all OpenStack services on the Compute nodes:

source overcloudrc

ssh ${FIRST_CONTROLLER} -- sudo pcs property set stonith-enabled=false 

helper=iha-helper-stop-services.sh
cat <<EOF > $helper
set -ex
openstack-service stop
openstack-service disable
systemctl stop libvirtd
systemctl disable libvirtd
EOF
for node in $COMPUTES; do scp $helper ${node}: ; done
for node in $COMPUTES; do ssh ${node} -- sudo bash $helper ; done

# 2. Create an authentication key for use with pacemaker-remote.

dd if=/dev/urandom of=./authkey bs=4096 count=1

# 3. Copy this key to the director node, and then to the remaining Compute and Controller nodes:

helper=iha-helper-fix-auth.sh
cat <<EOF > $helper
set -ex

mkdir -p --mode=0750 /etc/pacemaker/
chgrp haclient /etc/pacemaker
mv authkey /etc/pacemaker/
chown root:haclient /etc/pacemaker/authkey
EOF
for node in $COMPUTES $CONTROLLERS; do scp ./authkey $helper ${node}: ; done
for node in $COMPUTES $CONTROLLERS; do ssh ${node} -- sudo bash $helper ; done

# 4. Enable pacemaker-remote on all Compute nodes:

for compute in $COMPUTES; do ssh ${compute} -- sudo systemctl enable pacemaker_remote; done
for compute in $COMPUTES; do ssh ${compute} -- sudo systemctl start pacemaker_remote; done

# 5. Confirm that the required versions of the pacemaker (1.1.13-10.el7_2.2.x86_64), fence-agents (fence-agents-all-4.0.11-27.el7_2.5.x86_64) and resource-agents (3.9.5-54.el7_2.6.x86_64`) packages are installed on the controller and Compute nodes:
for compute in $COMPUTES; do ssh ${compute} -- rpm -qa | egrep '(pacemaker|fence-agents|resource-agents)' ; done

# 6.a Apply the following constraint workarounds required for BZ#1257414:

#Note: This issue has been addressed in RHSA-2015:1862 and might not be required for your environment.

#controller-1 # sudo pcs constraint order start openstack-nova-novncproxy-clone then openstack-nova-api-clone
#controller-1 # sudo pcs constraint order start rabbitmq-clone then openstack-keystone-clone
#controller-1 # sudo pcs constraint order promote galera-master then openstack-keystone-clone
#controller-1 # sudo pcs constraint order start haproxy-clone then openstack-keystone-clone
#controller-1 # sudo pcs constraint order start memcached-clone then openstack-keystone-clone
#controller-1 # sudo pcs constraint order promote redis-master then start openstack-ceilometer-central-clone require-all=false
#controller-1 # sudo pcs resource defaults resource-stickiness=INFINITY

#6.b Apply the following constraint workarounds required for BZ#1295835:

#Note: This issue has been addressed in RHBA-2016:0264-1 and might not be required for your environment.

#sudo pcs config | grep systemd | awk '{print $2}' | while read RESOURCE; do sudo pcs resource update $RESOURCE op start timeout=200s op stop timeout=200s; done"

# 7. Create a NovaEvacuate active/passive resource using the overcloudrc file to provide the auth_url, username, tenant and password values:
# 8. Confirm that nova-evacuate is started after the floating IP resources, and the Image Service (glance), OpenStack Networking (neutron), Compute (nova) services:

helper=iha-helper-create-evacuate.sh
cat <<EOF > $helper
set -ex

pcs resource create nova-evacuate ocf:openstack:NovaEvacuate auth_url=$OS_AUTH_URL username=$OS_USERNAME password=$OS_PASSWORD tenant_name=$OS_TENANT_NAME no_shared_storage=1 
for i in \$(sudo pcs status | grep IP | awk '{ print \$1 }'); do sudo pcs constraint order start \$i then nova-evacuate ; done
for i in openstack-glance-api-clone neutron-metadata-agent-clone openstack-nova-conductor-clone; do sudo pcs constraint order start \$i then nova-evacuate require-all=false ; done
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper

# Note: If you are not using shared storage, include the no_shared_storage=1 option in your resource create ... command above. See Exception for shared storage for more information.

# 9. Disable all OpenStack resources across the control plane:

# Depending on the time needed to stop Identity Service (and on the power of your hardware) you can consider increasing the timeout period (--wait).
# OSP8: ssh ${FIRST_CONTROLLER} -- sudo pcs resource disable openstack-keystone --wait=600s
# OSP9+:
ssh ${FIRST_CONTROLLER} -- sudo pcs resource disable openstack-core-clone --wait=600s


# 10. Create a list of the current controllers using cibadmin data :

#controller-1 # controllers=$(sudo cibadmin -Q -o nodes | grep uname | sed s/.*uname..// | awk -F\" '{print $1}')
#controller-1 # echo $controllers

# 11. Use this list to tag these nodes as controllers with the osprole=controller property:
# 12. Build a list of stonith devices already present in the environment:
# 13. Tag the control plane services to make sure they only run on the controllers identified above, skipping any stonith devices listed:

helper=iha-helper-tag-controllers.sh
cat <<EOF > $helper
set -ex

for controller in ${CONTROLLERS}; do pcs property set --node \${controller} osprole=controller ; done
stonithdevs=\$(pcs stonith | awk '{print \$1}')
for i in \$(cibadmin -Q --xpath //primitive --node-path | tr ' ' '\n' | awk -F "id='" '{print \$2}' | awk -F "'" '{print \$1}' | uniq); do
    found=0
    if [ -n "\$stonithdevs" ]; then
        for x in \$stonithdevs; do
            if [ \$x = \$i ]; then
                found=1
            fi
        done
    fi
    if [ \$found = 0 ]; then
        pcs constraint location \$i rule resource-discovery=exclusive score=0 osprole eq controller
    fi
done
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper

# 14. Begin to populate the Compute node resources within pacemaker, starting with neutron-openvswitch-agent:

helper=fix-compute.sh
cat <<EOF > $helper
set -x
grep crudini /usr/lib/ocf/resource.d/openstack/nova-compute-wait
if [ \$? != 0 ]; then
    set -e
    patch -p1  /usr/lib/ocf/resource.d/openstack/nova-compute-wait \${PWD}/bz1380314-nova-compute-wait-fix-invalid-hostname-issue.patch
fi
EOF
for node in $COMPUTES; do scp bz1380314-nova-compute-wait-fix-invalid-hostname-issue.patch $helper ${node}: ; done
for node in $COMPUTES; do ssh ${node} -- sudo bash $helper ; done

helper=iha-helper-create-compute-resources.sh
cat <<EOF > $helper
set -ex

pcs resource create neutron-openvswitch-agent-compute systemd:neutron-openvswitch-agent op start timeout=200s op stop timeout=200s --clone interleave=true --disabled --force
pcs constraint location neutron-openvswitch-agent-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start neutron-server-clone then neutron-openvswitch-agent-compute-clone require-all=false

# Then the Compute libvirtd resource:

pcs resource create libvirtd-compute systemd:libvirtd op start timeout=200s op stop timeout=200s --clone interleave=true --disabled --force
pcs constraint location libvirtd-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start neutron-openvswitch-agent-compute-clone then libvirtd-compute-clone
pcs constraint colocation add libvirtd-compute-clone with neutron-openvswitch-agent-compute-clone

# Then the openstack-ceilometer-compute resource:

pcs resource create ceilometer-compute systemd:openstack-ceilometer-compute op start timeout=200s op stop timeout=200s --clone interleave=true --disabled --force
pcs constraint location ceilometer-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start openstack-ceilometer-notification-clone then ceilometer-compute-clone require-all=false
pcs constraint order start libvirtd-compute-clone then ceilometer-compute-clone
pcs constraint colocation add ceilometer-compute-clone with libvirtd-compute-clone

# Then the nova-compute resource:

pcs resource create nova-compute-checkevacuate ocf:openstack:nova-compute-wait auth_url=$OS_AUTH_URL username=$OS_USERNAME password=$OS_PASSWORD tenant_name=$OS_TENANT_NAME domain=localdomain op start timeout=300 --clone interleave=true --disabled --force

pcs constraint location nova-compute-checkevacuate-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start openstack-nova-conductor-clone then nova-compute-checkevacuate-clone require-all=false
pcs resource create nova-compute systemd:openstack-nova-compute op start timeout=200s op stop timeout=200s --clone interleave=true --disabled --force
pcs constraint location nova-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute
pcs constraint order start nova-compute-checkevacuate-clone then nova-compute-clone require-all=true
pcs constraint order start nova-compute-clone then nova-evacuate require-all=false
pcs constraint order start libvirtd-compute-clone then nova-compute-clone
pcs constraint colocation add nova-compute-clone with libvirtd-compute-clone
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper

# 16. Create a seperate fence-nova stonith device:


helper=iha-helper-create-nova-fence.sh
cat <<EOF > $helper
set -ex

pcs stonith create fence-nova fence_compute auth-url=$OS_AUTH_URL login=$OS_USERNAME passwd=$OS_PASSWORD tenant-name=$OS_TENANT_NAME domain=localdomain record-only=1 --force
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper

# 17. Make certain the Compute nodes are able to recover after fencing:

ssh ${FIRST_CONTROLLER} -- sudo pcs property set cluster-recheck-interval=1min

# 18. Create Compute node resources and set the stonith level 1 to include both the nodes's physical fence device and fence-nova:

helper=iha-helper-create-computes.sh
cat <<EOF > $helper
set -ex

for node in $COMPUTES; do
    pcs resource create \${node} ocf:pacemaker:remote reconnect_interval=60 op monitor interval=20
    pcs property set --node \${node} osprole=compute
    pcs stonith level add 1 \${node} shooter,fence-nova
done
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper


# 19. Enable the control and Compute plane services:

helper=iha-helper-enable-services.sh
cat <<EOF > $helper
set -ex

#pcs resource enable openstack-keystone
pcs resource enable openstack-core
pcs resource enable neutron-openvswitch-agent-compute
pcs resource enable libvirtd-compute
pcs resource enable ceilometer-compute
pcs resource enable nova-compute-checkevacuate
pcs resource enable nova-compute
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper

# 20. Allow some time for the environment to settle before cleaning up any failed resources:

helper=iha-helper-cleanup.sh
cat <<EOF > $helper
set -ex

sleep 60
pcs resource cleanup
pcs status
echo pcs property set stonith-enabled=true
EOF
scp $helper ${FIRST_CONTROLLER}:
ssh ${FIRST_CONTROLLER} -- sudo bash $helper


#Test High Availability

#Note: These steps deliberately reboot the Compute node without warning.

#1. The following step boots an instance on the overcloud, and then crashes the Compute node:

#stack@director # . overcloudrc
#stack@director # nova boot --image cirros --flavor 2 test-failover
#stack@director # nova list --fields name,status,host
#stack@director # . stackrc
#stack@director # ssh -lheat-admin compute-n
#compute-n # sudo su -
#root@compute-n # echo c > /proc/sysrq-trigger
#
#2. A short time later, the instance should be restarted on a working Compute node:
#
#stack@director # nova list --fields name,status,host
#stack@director # nova service-list


# TEST/create your first network
# It is not possible to test neutron completely until the full deployment is complete as it is required to run instances to verify network connectivity. 

. ${PHD_VAR_env_configdir}/keystonerc_admin

# WARNING: openstack client is NOT ready to manage neutron!

neutron net-create internal_lan
neutron subnet-create --ip_version 4 --gateway 192.168.100.1 --name "internal_subnet" internal_lan 192.168.100.0/24
neutron net-create public_lan --router:external
neutron subnet-create --gateway 10.16.151.254 --allocation-pool   start=10.16.144.76,end=10.16.144.83 --disable-dhcp --name public_subnet   public_lan 10.16.144.0/21
neutron router-create router
neutron router-gateway-set router public_lan
neutron router-interface-add router internal_subnet

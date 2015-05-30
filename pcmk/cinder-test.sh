. ${PHD_VAR_env_configdir}/keystonerc_admin

openstack volume list
openstack volume create --size 10 test-volume
openstack volume list
openstack volume delete test-volume
openstack volume list

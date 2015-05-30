. ${PHD_VAR_env_configdir}/keystonerc_admin

openstack container list
openstack container create test
openstack container list

openstack object list test
truncate --size=1M /tmp/foobar
openstack object create test /tmp/foobar
openstack object list test
openstack object delete test /tmp/foobar
openstack object list test

openstack container delete test
openstack container list

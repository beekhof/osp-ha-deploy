. ${PHD_VAR_env_configdir}/keystonerc_admin

openstack image create --container-format bare --disk-format qcow2 --public --location http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img cirros

openstack image list

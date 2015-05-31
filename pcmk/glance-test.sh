. ${PHD_VAR_env_configdir}/keystonerc_admin

if [ ! -f ${PHD_VAR_env_configdir}/cirros-0.3.2-x86_64-disk.img ]; then
	wget -O ${PHD_VAR_env_configdir}/cirros-0.3.2-x86_64-disk.img http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
fi

openstack image create --container-format bare --disk-format qcow2 --public --file ${PHD_VAR_env_configdir}/cirros-0.3.2-x86_64-disk.img cirros

openstack image list

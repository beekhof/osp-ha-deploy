. ${PHD_VAR_env_configdir}/keystonerc_admin

glance image-create --name "cirros" --is-public true --disk-format qcow2  --container-format bare --location http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img

glance image-list
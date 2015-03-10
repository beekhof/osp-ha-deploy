. ${PHD_VAR_env_configdir}/keystonerc_admin

cinder list
cinder create 10
cinder list
cinder delete $(cinder list | grep available | awk '{print $2}')
cinder list
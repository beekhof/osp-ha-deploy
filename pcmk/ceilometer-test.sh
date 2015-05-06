. ${PHD_VAR_env_configdir}/keystonerc_admin
for m in storage.objects image network volume instance ; do ceilometer sample-list -m $m | tail -2 ; done

# https://bugzilla.redhat.com/show_bug.cgi?id=1127526#c2 <- for A/A testing

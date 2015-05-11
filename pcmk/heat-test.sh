# TEST:
# Requires a compute node!

. ${PHD_VAR_env_configdir}/keystonerc_admin

nova keypair-add --pub_key ~/.ssh/authorized_keys heat-userkey-test

cat > /root/ha_test.yaml << EOF
heat_template_version: 2013-05-23

description: >
  HA test.

parameters:
  key_name:
    type: string
    description: Name of keypair to assign to servers
  image:
    type: string
    description: Name of image to use for servers
  flavor:
    type: string
    description: Flavor to use for servers
  private_net_id:
    type: string
    description: ID of private network into which servers get deployed
  private_subnet_id:
    type: string
    description: ID of private sub network into which servers get deployed

resources:
  server1:
    type: OS::Nova::Server
    properties:
      name: Server1
      image: { get_param: image }
      flavor: { get_param: flavor }
      key_name: { get_param: key_name }
      networks:
        - port: { get_resource: server1_port }

  server1_port:
    type: OS::Neutron::Port
    properties:
      network_id: { get_param: private_net_id }
      fixed_ips:
        - subnet_id: { get_param: private_subnet_id }

outputs:
  server1_private_ip:
    description: IP address of server1 in private network
    value: { get_attr: [ server1, first_address ] }
EOF

privatenetid=$(neutron net-list |grep internal_lan | awk '{print $2}')
privatesubnetid=$(neutron subnet-list |grep internal_subnet|awk '{print $2}')

heat   stack-create testtest --template-file=/root/ha_test.yaml --parameters="key_name=heat-userkey-test;image=cirros;flavor=m1.large;private_net_id=$privatenetid;private_subnet_id=$privatesubnetid"

heat stack-list

heat stack-delete testtest


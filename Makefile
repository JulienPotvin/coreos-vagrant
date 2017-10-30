# Boots a 3-node etcd cluster on 172.17.8.10{1,2,3}
etcd:
	vagrant destroy -f  \
	&& vagrant reload \
	&& vagrant up \
	&& curl -sL http://172.17.8.101:2379/v2/keys/message -X PUT -d value="test12" > /dev/null \
	&& curl -sL http://172.17.8.102:2379/v2/keys/message | grep "test12" | wc -l | awk '{ if ($$1 == 0) print "etcd provisioning failed"; else print "etcd is up" }'

master:
	vagrant destroy -f  && vagrant reload && vagrant up && vagrant ssh controller-01

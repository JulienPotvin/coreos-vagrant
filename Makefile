etcd:
	vagrant destroy -f  \
	&& vagrant reload \
	&& vagrant up \
	&& curl -sL http://172.17.8.101:2379/v2/keys/message -X PUT -d value="test12" > /dev/null \
	&& curl -sL http://172.17.8.102:2379/v2/keys/message | grep "test12" | wc -l | awk '{ if ($$1 == 0) print "etcd provisioning failed"; else print "etcd is up" }'

kubernetes:
	vagrant destroy -f  && vagrant reload && vagrant up

#TODO: Unhardcode IPs
kubectl:
	MASTER_ENDPOINT=https://172.17.8.201 CA_CERT=./ssl/ca.pem ADMIN_KEY=./ssl/admin-key.pem ADMIN_CERT=./ssl/admin.pem ./install_kubectl.sh 

deploy_addons:
	DNS_SERVICE_IP=10.3.0.10 DIR=./addons ./deploy_addons.sh


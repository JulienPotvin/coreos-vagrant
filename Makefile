etcd:
	vagrant destroy -f  \
	&& vagrant reload \
	&& vagrant up \
	&& curl -sL http://172.17.8.101:2379/v2/keys/message -X PUT -d value="test12" > /dev/null \
	&& curl -sL http://172.17.8.102:2379/v2/keys/message | grep "test12" | wc -l | awk '{ if ($$1 == 0) print "etcd provisioning failed"; else print "etcd is up" }'

kubernetes:
	vagrant destroy -f  && vagrant reload && vagrant up && vagrant ssh controller-01

addons:
	DNS_SERVICE_IP=10.3.0.10 DIR=./addons ./deploy_addons.sh

dashboard: 
	kubectl port-forward $(kubectl get pods --namespace=kube-system | grep dashboard | awk '{print$1}') 9090 --namespace=kube-system
	open http://127.0.0.1:9090/


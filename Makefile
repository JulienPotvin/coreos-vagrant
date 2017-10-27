
# Boots a 3-node etcd cluster on 172.17.8.10{1,2,3}
etcd:
	vagrant destroy -f  && vagrant reload && vagrant up && vagrant ssh etcd-01

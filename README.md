# MongoDB-in-Kubernetes
MongoDB Sharded cluster deployed in K8s cluster

### Deployment of pods for Shard and Config server:

- Here the shard replicaset stores actual data or chunks (collection of documents) and config servers replicaset stores metadata and config information of the mongodb cluster. 

- In k8s cluster we create a headless service and statefulsets for the deployment of shards and config server pods. When headless service combined with statefulsets, k8s provides a unique DNS name for each pods which resolves to IP address of pods and these names doesn't  change even when the pods are rescheduled, so all the replica sets within the shards or config server can still communicate with each other.  

- There are other configuration that are done in yaml definitions like specifying the pod affinity, defining readiness/liveness probes, volume claim templates for persistent volumes and other container specific config for mongodb cluster. 

```
#shards
kubectl create -f mongodbShardReplicaset.yaml
kubectl get pods -w -l role=mongoshard
kubectl describe pods mongodbshardstateful-0
 
#configserver
kubectl create -f mongodbConfigReplicaset.yaml
kubectl get pods -w -l role=mongoconfig
kubectl describe pods mongodbconfigstateful-0
```

- Once the deployment of pods are completed , Initiate the shard and config replicaset with rs.initiate() [run this script replicasetInitiate.sh] which will assign primary/secondary state to replica sets. Here each shard and config server are deployed with 3 replicas(1 primary +2 secondary/Arbiter) to maintain the quorum when one of the node goes down, the mongodb should be able to vote and pick another primary shard within the replicaset. 

```
#Run
replicasetInitiate.sh 
#Check the status of replicas set
kubectl exec mongodbshardstateful-0 -c mongodshardcontainer -- mongo --eval 'rs.status()' 
kubectl exec mongodbconfigstateful-0 -c mongodconfigcontainer -- mongo --eval 'rs.status()'

```

#### Deploy Router pod in k8s

```
#Start the routers
kubectl create -f mongodbRouter.yaml
#Get the status
kubectl get pods -w -l role=mongorouter
kubectl describe pods mongosrouter-0
--------------------
#Add Shard to router
#Run this script
addShardsRouter.sh
#Get the status of the shard on routers
kubectl exec mongosrouter-0 -c mongosroutercontainer -- mongo --eval 'sh.status()'
```

#### Insert documents and validate shard distribution:
- Create DB/Collection and Insert some 1000 record

```
#Access the router
kubectl exec -it mongosrouter-0 -c mongosroutercontainer bash
#Create DB/collection and enable hash key sharding
mongo
use nbxdb
sh.enableSharding("nbxdb")
sh.shardCollection("nbxdb.nbximage", {"_id" : "hashed"})
show dbs
show collections
#INSERT 1000 documents
for (var i = 1; i <= 1000; i++) {db.nbximage.insert([{client:"nbximageclient1dokershard"+i, master:"11111111111111111"+i, data: "ytyyytytyyytytyyyytytyyytyytyt"+i }]) }
#VERIFY
db.nbximage.find({})
```

- Get the shard distribution status with 1 shard replicaset
```
#Access the router
kubectl exec -it mongosrouter-0 -c mongosroutercontainer bash
#Create DB/collection and enable hash key sharding
mongo
#Get the shard distribution status
db.nbximage.getShardDistribution()
 
mongos> db.nbximage.getShardDistribution()
Shard mongoreplicaset1shard at mongoreplicaset1shard/mongodbshardstateful-0.mongodbshardservice.default.svc.cluster.local:27017,mongodbshardstateful-1.mongodbshardservice.default.svc.cluster.local:27017,mongodbshardstateful-2.mongodbshardservice.default.svc.cluster.local:27017
 data : 136KiB docs : 1000 chunks : 2
 estimated data per chunk : 68KiB
 estimated docs per chunk : 500
Totals
 data : 136KiB docs : 1000 chunks : 2
 Shard mongoreplicaset1shard contains 100% data, 100% docs in cluster, avg obj size on shard : 139B
 ```
 - From the above shard distribution status, the single shard replicaset holds the two chunks where documents are split based on the shard hash key.
 
 




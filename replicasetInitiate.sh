#!/bin/bash
# This script configures replica set by adding members for Shard and Config server and making mongos router aware of sharded replica set.

#define vars
config_replicasetName=mongoreplicaset1config
config_container=mongodconfigcontainer
config_shortName=mongodbconfigstateful 
shard_replicasetName=mongoreplicaset1shard
shard_container=mongodshardcontainer
shard_shortName=mongodbshardstateful
router_pod1=mongosrouter-0
router_container1=mongosroutercontainer
shardreplicaset=mongoreplicaset1shard
mongoport=27017
declare -a shard1pod
declare -a config1pod

getfqdn_pods() {
 echo "Get fqdn for shards and config replicaset..."
 #Get FQDN for shard replicaset
 num=0
 shardarray=(`kubectl get --no-headers=true pods -l role=mongoshard -o custom-columns=:metadata.name`)
 for i in ${shardarray[@]};do
  echo $i
  shard1pod[num++]=`kubectl exec $i -- hostname -f`
 done

 #Get FQDN for configserver replicaset
 num=0
 configarray=(`kubectl get --no-headers=true pods -l role=mongoconfig -o custom-columns=:metadata.name`)
 for i in ${configarray[@]};do
  echo $i
  config1pod[num++]=`kubectl exec $i -- hostname -f`
 done
}

replicasetInit_ShardandConfig() {
   echo "Map Config server replica set with rs.initiate ..."
   #replicaset init on config server
   kubectl exec ${config_shortName}-0 -c ${config_container} -- bash -c "echo 'rs.initiate({_id:\"${config_replicasetName}\",\
   members:[{_id:0,host:\"${config1pod[0]}:${mongoport}\"},{_id:1,host:\"${config1pod[1]}:${mongoport}\"},{_id:2,host:\"${config1pod[2]}:${mongoport}\"} ]})' |mongo "
   sleep 5

   #Get the config status
   #kubectl exec ${config_shortName}-0 -c ${config_container} -- mongo --eval 'rs.status();'
  
   
   echo "Map Shard replica set to its associated members with rs.initiate..."
   #Map Shard replica set to its associated members with rs.initiate
   kubectl exec ${shard_shortName}-0 -c ${shard_container} -- bash -c "echo 'rs.initiate({_id :\"${shard_replicasetName}\",\
   members: [{ _id:0, host:\" ${shard1pod[0]}:${mongoport}\" },{ _id:1, host: \"${shard1pod[1]}:${mongoport}\" },{ _id:2, host: \"${shard1pod[2]}:${mongoport}\" }]})'|mongo "
   sleep 5
   
   #get shard status
   #kubectl exec ${shard_shortName}-0 -c ${shard_container}  -- mongo --eval 'rs.status();'
}

replicasetInit_statuscheck() {
   echo "Check the status of mongoDB shard and config replica Sets is updated..."
   #Check the status for shards and config replica set
   #myState: 0(STARTUP) 5(STARTUP2) 1 (Primary) 2 (Secondary)
   for i in 0 1 2; do
     shardstatus=`kubectl exec ${config_shortName}-${i} -c ${config_container} -- mongo --quiet --eval 'rs.status().myState;'` 
     echo "shard_status:"$shardstatus 
     kubectl exec ${config_shortName}-${i} -c ${config_container} -- mongo --quiet --eval \
     'while ( (rs.status().hasOwnProperty("myState")) && ((rs.status().myState == 0))) { print("..."); sleep(2000); };'
   done
   
   #Get the config status
   kubectl exec ${config_shortName}-0 -c ${config_container} -- mongo --eval 'rs.status();'

   for i in 0 1 2; do
     shardstatus=`kubectl exec ${shard_shortName}-${i} -c ${shard_container} -- mongo --quiet --eval 'rs.status().myState;'` 
     echo "shard_status:"$shardstatus
     kubectl exec ${shard_shortName}-${i} -c ${shard_container} -- mongo --quiet --eval \
     'while ((rs.status().hasOwnProperty("myState")) && ((rs.status().myState == 0) )) { print("..."); sleep(2000); };'
   done
 
   #get shard status
   kubectl exec ${shard_shortName}-0 -c ${shard_container}  -- mongo --eval 'rs.status();'
   echo "Status of mongoDB Replica Sets updated!"
}

<< "Comment"
addshard_router() {
  kubectl create -f "/home/yjayapra/.kube/mongodbRouter.yaml"
  echo "waiting to get status from mongos routers..."
  sleep 5
  #TODO wait until all the pods are tsrated and in ready state  
  until kubectl --v=0 exec ${router_pod1} -c ${router_container1} -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
  done

  # Add Shards on routers
  echo "Configure router to be aware of the Shards, performing addshard().."
  kubectl exec ${router_pod1}  -c ${router_container1} -- bash -c "echo 'sh.addShard(\"${shardreplicaset}/${shard1pod[0]}:${mongoport}\")' |mongo "
  echo "Adding shard completed on routers"
  sleep 3
  kubectl exec ${router_pod1} -c ${router_container1} -- mongo --eval 'sh.status()'
  
}
Comment

#Invoke functions
getfqdn_pods
replicasetInit_ShardandConfig
replicasetInit_statuscheck
#addshard_router


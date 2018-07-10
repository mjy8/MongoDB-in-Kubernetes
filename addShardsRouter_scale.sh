#!/bin/bash
#Add shard to router 

router_pod1=mongosrouter-0
router_container1=mongosroutercontainer
shardreplicaset=mongoreplicaset2shard
shard2pod=mongodbshardstateful2-0.mongodbshardservice2.default.svc.cluster.local
mongoport=27017
shard_container=mongodshardcontainer
shard_shortName=mongodbshardstateful2

declare -a shard1pod

<< "Comment"
 echo "Get fqdn for shards and config replicaset..."
 #Get FQDN for shard replicaset
 num=0
 shardarray=(`kubectl get --no-headers=true pods -l role=mongoshard -o custom-columns=:metadata.name`)
 for i in ${shardarray[@]};do
  echo $i
  shard1pod[num++]=`kubectl exec $i -- hostname -f`
 done
Comment

  echo "Map Shard replica set to its associated members with rs.initiate..."
  #Map Shard replica set to its associated members with rs.initiate
  kubectl exec ${shard_shortName}-0 -c ${shard_container} -- bash -c "echo 'rs.initiate({_id :\"${shardreplicaset}\",\
  members: [{ _id:0, host:\" ${shard2pod}:${mongoport}\" }]})'|mongo "
  sleep 5

  #check the status of shard and wait to get updated 
  echo "waiting for the shard status to get updated.."
  for i in 0 ; do
     shardstatus=`kubectl exec ${shard_shortName}-${i} -c ${shard_container} -- mongo --quiet --eval 'rs.status().myState;'`
     echo "shard_status:"$shardstatus
     kubectl exec ${shard_shortName}-${i} -c ${shard_container} -- mongo --quiet --eval \
     'while ((rs.status().hasOwnProperty("myState")) && ((rs.status().myState == 0) )) { print("..."); sleep(2000); };'
  done


  #get shard status
  kubectl exec ${shard_shortName}-0 -c ${shard_container}  -- mongo --eval 'rs.status();'
  sleep 3 

 #Add Shards on routers
  echo "Configure router to be aware of the Shards, performing addshard().."
  kubectl exec ${router_pod1}  -c ${router_container1} -- bash -c "echo 'sh.addShard(\"${shardreplicaset}/${shard2pod}:${mongoport}\")' |mongo "
  echo "Adding shard completed on routers"
  sleep 3
  kubectl exec ${router_pod1} -c ${router_container1} -- mongo --eval 'sh.status()'



#!/bin/bash

shard_container=mongodshardcontainer
shard_shortName=mongodbshardstateful


#scale the replicas for shard replicaset
#kubectl scale sts mongodbshardstateful --replicas=4
#sleep 5
primaryshard=''

#Check the status of shard replica set
#for i in 3 4 ; do
 #    shardstatus=`kubectl exec ${shard_shortName}-${i} -c ${shard_container} -- mongo --quiet --eval 'rs.status().myState;'` 
  #   echo "shard_status:"$shardstatus
   #  kubectl exec ${shard_shortName}-${i} -c ${shard_container} -- mongo --quiet --eval \
    # 'while ((rs.status().hasOwnProperty("myState")) && ((rs.status().myState == 0) )) { print("..."); sleep(2000); };'
#done
#echo "Status of mongoDB Replica Sets updated!"

#Get the primary shard 
shardarray=(`kubectl get --no-headers=true pods -l role=mongoshard -o custom-columns=:metadata.name`)
 for i in ${shardarray[@]};do
  primary=`kubectl exec $i -c ${shard_container} -- mongo --quiet --eval 'rs.isMaster().ismaster'`
  if [ $primary = 'true' ];
    then
       primaryshard=$i
       break
  fi
 done

echo "Primary shard discovered:"$primaryshard

#Set the replicaset with rs.add() 
for i in 3; do
 kubectl exec ${primaryshard} -c ${shard_container}  -- bash -c "echo \
'rs.add( {host: \"${shard_shortName}-${i}.mongodbshardservice.default.svc.cluster.local:27017\",priority: 1, votes: 1})' | mongo "
done


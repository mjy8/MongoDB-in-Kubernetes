#!//bin/sh

shard1_pod0=""
shard1_pod1=""
shard1_pod2=""
num=0
declare -a shard1pod
array=(`kubectl get --no-headers=true pods -l role=mongoshard -o custom-columns=:metadata.name`)

for i in ${array[@]};do
 echo $i
 shard1pod[num++]=`kubectl exec $i -- hostname -f`
 echo ${shard1pod[--num]}
 #num=$((num+1))
done
for i in 0 1 2; do
     echo $i
     shardstatus=`kubectl exec mongodbconfigstateful-${i} -c mongodconfigcontainer -- mongo --quiet --eval 'rs.status().myState;'`
     echo "shard_status:"$shardstatus
     kubectl exec mongodbconfigstateful-${i} -c mongodconfigcontainer -- mongo --quiet --eval \
     'while ((rs.status().hasOwnProperty("myState")) && ((rs.status().myState == 0))) { print("..."+rs.status().myState); sleep(2000); };'
done


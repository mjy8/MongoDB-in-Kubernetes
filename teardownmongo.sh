#!/bin/bash

#Cleanup the Shard replicaset
#for i in 0 1 2 3 4 5
#do
 #kubectl exec mongodbshardstateful-${i} -c mongodshardcontainer -- bash -c "rm -rfd /data/db"
#done 

kubectl delete statefulsets mongodbshardstateful
kubectl delete services mongodbshardservice

kubectl delete statefulsets mongodbshardstateful2
kubectl delete services mongodbshardservice2

kubectl delete pvc -l role=mongoshard
#kubectl delete pods mongodshard-0 --grace-period=0 --force


#Cleanup the config replicaset
#for i in 0 1 2 3 4 5
#do
 #kubectl exec mongodbconfigstateful-${i} -c mongodshardcontainer -- bash -c "rm -rfd /data/db"
#done 

#Cleanup the Config replicaset
kubectl delete statefulsets mongodbconfigstateful
kubectl delete services mongodbconfigservice

kubectl delete pvc -l role=mongoconfig

#Cleanup the Routers
kubectl delete statefulsets mongosrouter
kubectl delete services mongodbroutersvc


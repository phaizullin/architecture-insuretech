#!/bin/bash

kubectl delete -f hpa.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl get deployments,services,hpa,pods -l app=scaletestapp

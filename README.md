helm install local-confluent-kafka helm/cp-helm-charts
helm upgrade local-confluent-kafka helm/cp-helm-charts
helm uninstall local-confluent-kafka
kubectl get pods


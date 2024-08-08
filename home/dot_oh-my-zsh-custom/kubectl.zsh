function ep {
	kubectl exec -it $(kubectl get pods -o name | grep $1 -m 1) -- bash
}

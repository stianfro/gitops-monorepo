#!/bin/bash

export MINIKUBE=false

BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)
BRIGHT=$(tput bold)
COLOR=$BLUE
STAR='🌟 '

printf "\n%s%s%s\n" "$STAR" "$COLOR" "checking for kind or minikube..."
if ! command -v kind &> /dev/null
then
  echo "kind could not be found, checking for minikube..."
  if ! command -v minikube &> /dev/null
  then
    echo "minikube could not be found. Please install minikube or kind and try again."
    exit 1
  else
    export MINIKUBE=true
  fi
fi

if [ $MINIKUBE == true ]
then
  echo "creating cluster with minikube..."
  if ! minikube start --addons ingress
  then
    echo "Failed to create minikube cluster. Exiting..."
    exit 1
  fi
else
  echo "creating cluster with kind..."
  if ! kind create cluster --name my-cluster --config .local/kind-config.yaml
  then
    echo "Failed to create kind cluster. Exiting..."
    exit 1
  fi
fi

if [[ $(kubectl config current-context) != "kind-my-cluster" ]] && [[ $(kubectl config current-context) != "minikube"  ]]
then
  echo "Current context is not kind-my-cluster. Please switch to the correct context and try again."
  exit 1
fi

if [[ $MINIKUBE == false ]]
then
  printf "\n%s%s%s\n" "$STAR" "$COLOR" "installing nginx ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || exit 1

fi

printf "\n%s%s%s\n" "$STAR" "$COLOR" "waiting for ingress controller to get ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

printf "\n%s%s%s\n" "$STAR" "$COLOR" "sleep for 10 seconds to allow ingress controller to get ready..."
sleep 10
printf "\n%s%s%s\n" "$STAR" "$COLOR" "installing argocd..."
kubectl apply -k .local/argo || exit 1

printf "\n%s%s%s\n" "$STAR" "$COLOR" "waiting for argocd to get ready..."
kubectl wait -n argocd \
  --for=condition=ready pod \
  --timeout=90s \
  --selector=app.kubernetes.io/name=argocd-server

argo_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argo_host=$(kubectl -n argocd get ingress argocd-server-ingress -o jsonpath="{.spec.rules[0].host}")
argo_path=$(kubectl get ingress -n argocd argocd-server-ingress -o jsonpath="{.spec.rules[0].http.paths[0].path}")
printf "\nArgoCD now available at http://%s%s" "${argo_host:=localhost}" "$argo_path"
printf "\nusername: %sadmin%s" "${BRIGHT}" "${NORMAL}"
printf "\npassword: %s%s%s\n" "${BRIGHT}" "$argo_password" "${NORMAL}"

kubectl apply -f iac/appset.yaml

# echo ""
# echo "You can now create a bootstrap app by running 'kubectl apply -f .bootstrap/dev.yaml'"

# if [[ $MINIKUBE == true ]]
# then
#   echo ""
#   printf "\n%s%s%s\n" "$STAR" "$COLOR" "starting minkube tunnel... Use a new terminal to run 'kubectl apply -f .bootstrap/dev.yaml'"
#   minikube tunnel
# fi

# Deployment Steps After Terraform Completes

## 1. Wait for Terraform Workflow ✅
- Monitor: https://github.com/MaripeddiSupraj/ai-gcp-infra/actions
- Expected time: ~10-15 minutes

## 2. Connect to GKE Cluster
```bash
gcloud container clusters get-credentials ai-chat-cluster --region us-central1
```

## 3. Build & Push Docker Image
```bash
cd app
docker build -t us-central1-docker.pkg.dev/$(gcloud config get-value project)/ai-chat-repo/ai-chat-app:latest .
docker push us-central1-docker.pkg.dev/$(gcloud config get-value project)/ai-chat-repo/ai-chat-app:latest
```

## 4. Deploy Application
```bash
cd ../k8s-manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress-nginx.yaml
```

## 5. Get External IP
```bash
kubectl get svc -n ingress-nginx
```

## 6. Test Application
```bash
curl http://<EXTERNAL-IP>
```

## 7. Then Review User Requirements
Once app is accessible, we'll implement what the user needs.

# GitHub Actions Self-hosted Runner on Cloud Run Worker Pools

```shell
PROJECT="YOUR-PROJECT-ID"
gcloud config set project "$PROJECT"
gcloud services enable \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com
cat private-key.pem | gcloud secrets create github-app-private-key --data-file=-
gcloud artifacts repositories create runner \
  --repository-format=docker \
  --location=asia-northeast1
docker build -t asia-northeast1-docker.pkg.dev/$PROJECT/runner/actions-runner:latest .
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
docker push asia-northeast1-docker.pkg.dev/$PROJECT/runner/actions-runner:latest
gcloud beta run worker-pools deploy actions-runner \
  --image asia-northeast1-docker.pkg.dev/$PROJECT/runner/actions-runner:latest \
  --region asia-northeast1 \
  --set-env-vars="GITHUB_APP_ID=$GITHUB_APP_ID" \
  --set-env-vars="GITHUB_APP_INSTALLATION_ID=$GITHUB_APP_INSTALLATION_ID" \
  --set-env-vars="GITHUB_REPOSITORY=$GITHUB_REPOSITORY" \
  --set-env-vars="GITHUB_APP_PRIVATE_KEY_SECRET_ID=github-app-private-key" \
  --set-env-vars="GITHUB_APP_PRIVATE_KEY_SECRET_VERSION=latest"
```

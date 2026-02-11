#!/bin/bash
set -e

# Cloud Run Deployment Script with Secret Manager
# This script securely deploys OpenClawBot using Google Cloud Secret Manager

PROJECT_ID="${GCP_PROJECT_ID:-xzerolab-480008}"
REGION="${GCP_REGION:-asia-northeast1}"
SERVICE_NAME="openclawbot-svc-plus"
GCS_BUCKET="${GCS_BUCKET_NAME:-openclawbot-data}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT_EMAIL:-openclawbot-sa@${PROJECT_ID}.iam.gserviceaccount.com}"
SECRET_NAME="internal-service-token"

echo "🚀 Deploying OpenClawBot to Cloud Run with Secret Manager..."
echo "   Project: $PROJECT_ID"
echo "   Region: $REGION"
echo "   Service: $SERVICE_NAME"
echo "   GCS Bucket: $GCS_BUCKET"
echo "   Secret: $SECRET_NAME"
echo ""

# Step 1: Create or update secret in Secret Manager
echo "🔐 Setting up Secret Manager..."
if gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "   ✅ Secret '${SECRET_NAME}' already exists"
else
  echo "   Creating secret '${SECRET_NAME}'..."
  # Use the shared INTERNAL_SERVICE_TOKEN
  echo -n "uTvryFvAbz6M5sRtmTaSTQY6otLZ95hneBsWqXu+35I=" | \
    gcloud secrets create "${SECRET_NAME}" \
      --data-file=- \
      --project="${PROJECT_ID}" \
      --replication-policy="automatic"
  echo "   ✅ Secret created"
fi

# Step 2: Create GCS bucket if it doesn't exist
echo "📦 Checking GCS bucket..."
if ! gsutil ls -b "gs://${GCS_BUCKET}" &>/dev/null; then
  echo "   Creating GCS bucket: ${GCS_BUCKET}"
  gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${GCS_BUCKET}"
  echo "   ✅ Bucket created"
else
  echo "   ✅ Bucket already exists"
fi

# Step 3: Create service account if it doesn't exist
echo "🔐 Checking service account..."
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "   Creating service account..."
  gcloud iam service-accounts create "openclawbot-sa" \
    --display-name="OpenClawBot Service Account" \
    --project="${PROJECT_ID}"
  echo "   ✅ Service account created"
  echo "   ⏳ Waiting for service account to propagate..."
  sleep 10
else
  echo "   ✅ Service account already exists"
fi

# Step 4: Grant necessary permissions
echo "🔑 Granting permissions..."

# Grant GCS access
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/storage.objectAdmin" \
  --condition=None \
  --quiet

# Grant Secret Manager access
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor" \
  --project="${PROJECT_ID}" \
  --quiet

echo "   ✅ Permissions granted"

# Step 5: Build and deploy
echo "🏗️  Building and deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --source . \
  --platform managed \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --service-account "${SERVICE_ACCOUNT}" \
  --execution-environment gen2 \
  --cpu 2 \
  --memory 4Gi \
  --min-instances 1 \
  --max-instances 10 \
  --no-cpu-throttling \
  --allow-unauthenticated \
  --port 8080 \
  --update-secrets OPENCLAW_GATEWAY_TOKEN="${SECRET_NAME}:latest" \
  --set-env-vars OPENCLAW_GATEWAY_MODE=local \
  --add-volume name=gcs-data,type=cloud-storage,bucket="${GCS_BUCKET}" \
  --add-volume-mount volume=gcs-data,mount-path=/data

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Service URL:"
gcloud run services describe "${SERVICE_NAME}" \
  --platform managed \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --format 'value(status.url)'

echo ""
echo "🔐 Secret Manager:"
echo "   Secret: ${SECRET_NAME}"
echo "   Version: latest"
echo "   Shared with: console.svc.plus, accounts.svc.plus"

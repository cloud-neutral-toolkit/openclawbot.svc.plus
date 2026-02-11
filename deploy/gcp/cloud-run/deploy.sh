#!/bin/bash
set -e

# Cloud Run Deployment Script for OpenClawBot
# This script deploys the application to Google Cloud Run with GCS volume mounting

PROJECT_ID="${GCP_PROJECT_ID:-xzerolab-480008}"
REGION="${GCP_REGION:-asia-northeast1}"
SERVICE_NAME="openclawbot-svc-plus"
GCS_BUCKET="${GCS_BUCKET_NAME:-openclawbot-data}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT_EMAIL:-openclawbot-sa@${PROJECT_ID}.iam.gserviceaccount.com}"
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-mNrXA9Lm+5cs6wMziYMafJgkjTJg45OMiB1YTXEt5E8=}"

echo "🚀 Deploying OpenClawBot to Cloud Run..."
echo "   Project: $PROJECT_ID"
echo "   Region: $REGION"
echo "   Service: $SERVICE_NAME"
echo "   GCS Bucket: $GCS_BUCKET"
echo ""

# Step 1: Create GCS bucket if it doesn't exist
echo "📦 Checking GCS bucket..."
if ! gsutil ls -b "gs://${GCS_BUCKET}" &>/dev/null; then
  echo "   Creating GCS bucket: ${GCS_BUCKET}"
  gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${GCS_BUCKET}"
  echo "   ✅ Bucket created"
else
  echo "   ✅ Bucket already exists"
fi

# Step 2: Create service account if it doesn't exist
echo "🔐 Checking service account..."
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "   Creating service account..."
  gcloud iam service-accounts create "openclawbot-sa" \
    --display-name="OpenClawBot Service Account" \
    --project="${PROJECT_ID}"
  echo "   ✅ Service account created"
else
  echo "   ✅ Service account already exists"
fi

# Step 3: Grant necessary permissions
echo "🔑 Granting permissions..."
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/storage.objectAdmin" \
  --condition=None \
  --quiet

echo "   ✅ Permissions granted"

# Step 4: Build and deploy
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
  --set-env-vars OPENCLAW_GATEWAY_TOKEN="${GATEWAY_TOKEN}" \
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

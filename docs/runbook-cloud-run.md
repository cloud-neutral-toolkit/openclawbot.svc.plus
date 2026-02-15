# OpenClaw Cloud Run Deployment Runbook

This document describes the deployment process for OpenClaw on Google Cloud Run with GCS storage, and documents known issues and their resolutions.

## 1. Prerequisites

- Google Cloud Project with Cloud Run and Secret Manager enabled.
- GCS Bucket (e.g., `openclawbot-data`).
- Service Account with `Storage Object Admin` and `Secret Manager Secret Accessor` roles.

## 2. Environment Variables & Secrets

The following variables must be configured in the Cloud Run service:

| Variable                 | Source  | Description                                               |
| :----------------------- | :------ | :-------------------------------------------------------- |
| `NODE_ENV`               | Literal | Set to `production`.                                      |
| `OPENCLAW_STATE_DIR`     | Literal | Path to the GCS volume mount point (e.g., `/data`).       |
| `OPENCLAW_CONFIG_PATH`   | Literal | Path to the config file (e.g., `/data/openclaw.json`).    |
| `OPENCLAW_GATEWAY_MODE`  | Literal | Set to `local`.                                           |
| `INTERNAL_SERVICE_TOKEN` | Secret  | Gateway authentication token.                             |
| `Z_AI_API_KEY`           | Secret  | Zhipu AI API Key (automatically mapped to `ZAI_API_KEY`). |

## 3. Storage Configuration (GCS)

- Mount a GCS bucket to `/data`.
- Ensure `/data/openclaw.json` exists. For the best experience with the Control UI, use the following policy settings in `openclaw.json`:
  ```json
  "gateway": {
    "controlUi": {
      "enabled": true,
      "allowedOrigins": ["*"],
      "dangerouslyDisableDeviceAuth": true
    }
  }
  ```

## 4. Known Issues & Resolutions

### Gateway Token Mismatch (Browser Dashboard)

- **Problem**: Tokens containing the `+` character (common in Base64) are incorrectly decoded as spaces by `URLSearchParams` in the browser.
- **Error**: `disconnected (1008): unauthorized: gateway token mismatch`.
- **Resolution**: A fix was implemented in `ui/src/ui/app-settings.ts` to manually parse tokens from the URL hash to preserve special characters.

### Disconnected (1005): No Reason

- **Cause**: Connection interrupted without a close frame. Often caused by:
  - Container OOM (check Cloud Run memory limits, recommend >= 2GB).
  - Proxy timeout or reset.
  - Process crash during handshake.
- **Resolution**: Check Cloud Run logs for OOM or startup errors. Ensure `gateway.port` in `openclaw.json` matches the Cloud Run port (default 8080).

## 5. Deployment Commands

```bash
# Build and Push
gcloud builds submit --config cloudbuild.yaml .

# Manual Deploy Example
gcloud run deploy openclawbot-svc-plus \
  --image asia-northeast1-docker.pkg.dev/$PROJECT_ID/... \
  --update-secrets OPENCLAW_GATEWAY_TOKEN=internal-service-token:latest \
  --set-env-vars NODE_ENV=production,OPENCLAW_STATE_DIR=/data,OPENCLAW_CONFIG_PATH=/data/openclaw.json,OPENCLAW_GATEWAY_MODE=local \
  --add-volume name=gcs-data,type=cloud-storage,bucket=openclawbot-data \
  --add-volume-mount volume=gcs-data,mount-path=/data
```

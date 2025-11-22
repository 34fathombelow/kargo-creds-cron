#!/bin/sh
set -eu

NAMESPACE="${NAMESPACE:-akuity}"

# Server URL default
AKUITY_SERVER_URL="${AKUITY_SERVER_URL:-https://akuity.cloud}"

# Required: API key ID
if [ -z "${AKUITY_API_KEY_ID:-}" ]; then
  echo "ERROR: AKUITY_API_KEY_ID environment variable is not set." >&2
  exit 1
fi

# Required: API key secret value
if [ -z "${AKUITY_API_KEY_SECRET:-}" ]; then
  echo "ERROR: AKUITY_API_KEY_SECRET environment variable is not set." >&2
  exit 1
fi

# Required: organization name
if [ -z "${AKUITY_ORG_NAME:-}" ]; then
  echo "ERROR: AKUITY_ORG_NAME environment variable is not set." >&2
  exit 1
fi

# Required: Kargo instance name (new variable)
if [ -z "${KARGO_INSTANCE_NAME:-}" ]; then
  echo "ERROR: KARGO_INSTANCE_NAME environment variable is not set." >&2
  exit 1
fi

####################################################################################################
# AUTH CHECK
####################################################################################################
echo "Validating Akuity API key by listing Kargo instances for org '$AKUITY_ORG_NAME'..."

if ! akuity kargo instance list --org-name "$AKUITY_ORG_NAME" >/dev/null 2>&1; then
  echo "ERROR: Failed to authenticate with Akuity using API key."
  echo "       Check:"
  echo "         - AKUITY_API_KEY_ID"
  echo "         - AKUITY_API_KEY_SECRET"
  echo "         - AKUITY_SERVER_URL ($AKUITY_SERVER_URL)"
  echo "         - AKUITY_ORG_NAME ($AKUITY_ORG_NAME)"
  exit 1
fi
echo "Authentication OK"

####################################################################################################
# FIND KARGO CREDS SECRETS
####################################################################################################

echo "Searching for Kargo credential secrets in namespace '$NAMESPACE'"

# Find secrets with annotation: kargo.akuity.io/namespace (supports comma-separated values)
SECRET_NAMES="$(
  kubectl get secrets -n "$NAMESPACE" -o json | \
    yq '.items[] | select(.metadata.annotations."kargo.akuity.io/namespace" != null) | .metadata.name' - | \
    tr '\n' ' '
)"

if [ -z "$SECRET_NAMES" ]; then
  echo "No secrets found with annotation 'kargo.akuity.io/namespace' in namespace '$NAMESPACE'. Nothing to sync."
  exit 1
fi

WORKDIR="${KARGO_WORKDIR:-/tmp/kargo-files}"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

for SECRET in $SECRET_NAMES; do
  # Get comma-separated namespaces from annotation
  TARGET_NAMESPACES="$(kubectl get secret "$SECRET" -n "$NAMESPACE" \
    -o jsonpath='{.metadata.annotations.kargo\.akuity\.io/namespace}' 2>/dev/null || echo '')"

  if [ -z "$TARGET_NAMESPACES" ]; then
    echo "Warning: Secret '$SECRET' has annotation selector but no namespace annotation found, skipping"
    continue
  fi

  # Split comma-separated namespaces from annotation
  OLD_IFS="$IFS"
  IFS=','
  for TARGET_NAMESPACE_RAW in $TARGET_NAMESPACES; do
    TARGET_NAMESPACE=$(echo "$TARGET_NAMESPACE_RAW" | xargs)
    
    if [ -z "$TARGET_NAMESPACE" ]; then
      echo "Warning: Empty namespace found in annotation for secret '$SECRET', skipping"
      continue
    fi

    OUT_FILE="$WORKDIR/${SECRET}-${TARGET_NAMESPACE}.yaml"
    echo "Exporting secret '$SECRET' to namespace '$TARGET_NAMESPACE' → '$OUT_FILE'"

    kubectl get secret "$SECRET" -n "$NAMESPACE" -o yaml \
      | TARGET_NAMESPACE="$TARGET_NAMESPACE" yq '
          {
            "apiVersion": .apiVersion,
            "kind": .kind,
            "type": .type,
            "data": .data,
            "metadata": {
              "name": .metadata.name,
              "namespace": strenv(TARGET_NAMESPACE),
              "labels": .metadata.labels
            }
          }
        ' - \
      > "$OUT_FILE"
  done
  IFS="$OLD_IFS"
done

echo "Applying Kargo secrets from $WORKDIR"

akuity kargo apply -f "$WORKDIR" \
  --organization-name "$AKUITY_ORG_NAME" \
  --name "$KARGO_INSTANCE_NAME"

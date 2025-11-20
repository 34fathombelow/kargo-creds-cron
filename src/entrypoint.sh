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

SECRET_NAMES="$(
  kubectl get secrets -n "$NAMESPACE" \
    -l 'kargo.akuity.io/namespace' \
    -o jsonpath='{.items[*].metadata.name}'
)"

if [ -z "$SECRET_NAMES" ]; then
  echo "No secrets found with label 'kargo.akuity.io/namespace' in namespace '$NAMESPACE'. Nothing to sync."
  exit 1
fi

WORKDIR="${KARGO_WORKDIR:-/tmp/kargo-files}"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

for SECRET in $SECRET_NAMES; do
  OUT_FILE="$WORKDIR/${SECRET}.yaml"
  echo "Exporting secret '$SECRET' → '$OUT_FILE'"

  # Extract the namespace target from the label
  TARGET_NAMESPACE="$(kubectl get secret "$SECRET" -n "$NAMESPACE" \
    -o jsonpath='{.metadata.labels.kargo\.akuity\.io/namespace}')"

  # Get secret, drop annotations, and rewrite namespace using target namespace
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

echo "Applying Kargo secrets from $WORKDIR"

akuity kargo apply -f "$WORKDIR" \
  --organization-name "$AKUITY_ORG_NAME" \
  --name "$KARGO_INSTANCE_NAME"

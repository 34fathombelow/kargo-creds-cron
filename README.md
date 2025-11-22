# kargo-creds-cron:
`kargo-creds-cron` automates syncing Kargo credential Secrets into an Akuity-managed Kargo instance. It discovers annotated Secrets in the Kubernetes namespace where the chart is installed, rewrites their namespaces dynamically, and applies them to a target Kargo instance using the Akuity CLI.

This allows you to manage Kargo credentials declaratively via Secrets or preferably with a secrets management tool such as the External Secrets Operator.

## Features:
- Discovers Secrets annotated with `kargo.akuity.io/namespace` (supports comma-separated values for multiple namespaces)
- Supports single or multiple target namespaces
- Rewrites each Secret's `metadata.namespace` to the target namespace(s)
- Creates separate Secret files for each target namespace when multiple namespaces are specified
- Applies the transformed Secrets to a Kargo instance using:

  `akuity kargo apply -f /tmp/kargo-files`

- Authentication via Akuity API key (ID + secret)
- Optional management of the API key Secret through Helm
- CronJob-based automation
- Minimal RBAC (get + list on Secrets)
- Multi-arch compatible (amd64 + arm64)

## Requirements:
* Valid Akuity API key (ID + secret)
* Kargo Secrets must have annotation `kargo.akuity.io/namespace`
* Chart must be installed in the same namespace where the Secrets exist

## Secrets & Annotation Requirements:
All Kargo Secrets *must* exist in the namespace where the chart is deployed.

Every Secret intended for sync must include the `kargo.akuity.io/namespace` annotation which determines the namespace(s) the Secret will be rewritten into. The annotation value can be a single namespace or comma-separated multiple namespaces.

### Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitcreds
  namespace: akuity
  annotations:
    kargo.akuity.io/namespace: kargo-creds
  labels:
    kargo.akuity.io/cred-type: git
type: Opaque
data:
  repoURL: <base64>
  username: <base64>
  password: <base64>
```

After transformation, the Secret's namespace will be rewritten to the target namespace specified in the annotation.

For multiple namespaces, use comma-separated values in the annotation (e.g., `kargo.akuity.io/namespace: kargo-creds,kargo-staging,kargo-prod`). See the `example/` directory for complete examples including multiple namespace usage.

## Helm Chart Values:
| Key | Type | Description | Default |
|-----|------|-------------|---------|
| image.repository | string | Container repository | quay.io/34fathombelow/kargo-creds |
| image.tag | string | Image tag | v0.3 |
| image.pullPolicy | string | Kubernetes pull policy | Always |
| cronJob.name | string | CronJob name | kargo-creds-cron |
| cronJob.schedule | string | Cron schedule expression | 0 */10 * * * |
| rbac.create | bool | Whether to create RBAC objects | true |
| apiSecret.create | bool | Whether Helm should create the API key Secret | false |
| apiSecret.name | string | Name of the Secret | akuity-api-key |
| apiSecret.apiKeyId | string | Akuity API Key ID (required if create=true) | "" |
| apiSecret.apiKeySecret | string | Akuity API Key Secret (required if create=true) | "" |
| env.serverUrl | string | Akuity API URL | https://akuity.cloud |
| env.orgName | string | Akuity organization name | akuity-org |
| env.kargoInstanceName | string | Kargo instance in the organization | kargo-instance-name |
| env.extra | list | Additional environment variables | [] |

## Caveats:
* This tool does not implement a prune or delete mechanism.
Secrets applied to a Kargo instance will not be automatically removed if the originating Kubernetes Secret is deleted.

* As a result, removing credentials should be performed using the Akuity UI or API, ensuring the corresponding Kargo credential objects are deleted correctly.

* Support for automated pruning or reconciliation logic may be added in the future, but the current behavior is apply-only and intentionally conservative.

## Example Secrets:
Example credential Secrets are included in the `example/` directory of this repository:
- `example/secrets.yaml` - Examples for different credential types, including single and multiple namespace usage
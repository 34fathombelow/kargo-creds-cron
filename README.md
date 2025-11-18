# kargo-creds-sync:
`kargo-creds-sync` automates syncing Kargo credential Secrets into an Akuity-managed Kargo instance. It discovers labeled Secrets in the Kubernetes namespace where the chart is installed, rewrites their namespaces dynamically, and applies them to a target Kargo instance using the Akuity CLI.

This allows you to manage Kargo credentials declaratively via Secrets or preferably with a secrets manangment tool such as the External Secrets Operator.

## Features:
- Discovers Secrets labeled with:

  `kargo.akuity.io/namespace: <target-namespace>`

- Rewrites each Secret's `metadata.namespace` to the target namespace
- Applies the transformed Secrets to a Kargo instance using:

  `akuity kargo apply -f /tmp/kargo-files`

- Authentication via Akuity API key (ID + secret)
- Optional management of the API key Secret through Helm
- CronJob-based automation
- Minimal RBAC (get + list on Secrets)
- Multi-arch compatible (amd64 + arm64)

## Requirements:
* Valid Akuity API key (ID + secret)
* Kargo Secrets must be labeled with kargo.akuity.io/namespace
* Chart must be installed in the same namespace where the Secrets exist

## Secrets & Label Requirements:
All Kargo Secrets *must* exist in the namespace where the chart is deployed.

Every Secret intended for sync must include the following which determines the namespace the Secret will be rewritten into:

```yaml
metadata:
  labels:
    kargo.akuity.io/namespace: <target-namespace>
```

Example Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitcreds
  namespace: akuity
  labels:
    kargo.akuity.io/namespace: kargo-creds
    kargo.akuity.io/cred-type: git
type: Opaque
data:
  repoURL: <base64>
  username: <base64>
  password: <base64>
```

After transformation:

```yaml
metadata:
  namespace: kargo-creds
```

## Helm Chart Values:
| Key | Type | Description | Default |
|-----|------|-------------|---------|
| image.repository | string | Container repository | quay.io/34fathombelow/kargo-creds |
| image.tag | string | Image tag | v0.1 |
| image.pullPolicy | string | Kubernetes pull policy | Always |
| cronJob.name | string | CronJob name | kargo-creds-apply-cronjob |
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
Example credential Secrets are included in the `examples` directory of this repository. These demonstrate the expected format for Kargo credentials and the required labels.
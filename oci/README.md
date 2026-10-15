```bash
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: oci-vault
  namespace: default
spec:
  provider:
    oracle:
      vault: "PUT_YOUR_VAULT_OCID"
      region: "us-ashburn-1"
      principalType: InstancePrincipal
```
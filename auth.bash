
#!/usr/bin/env bash
set -euo pipefail

########################################
# Variables – replace placeholders below
########################################

KV_NAME="kv-testea-dev-chn-6z2f"
CLIENT_SECRET_KV_SECRET_NAME="backend-entra-app-secret"
APP_REG_NAME="testea-dev-chn-backend"
ACA_NAME="ca-testea-dev-chn-backend"
ACA_RESOURCE_GROUP="rg-testea-dev-chn-main"
PROTECTED_ROUTE="/"

########################################
# 0. Prerequisites
########################################

TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az ad app list --display-name $APP_REG_NAME --query "[0].appId" -o tsv)
CLIENT_SECRET=$(az keyvault secret show --vault-name $KV_NAME -n $CLIENT_SECRET_KV_SECRET_NAME | jq -r .value) # e.g. 00000000-0000-0000-0000-000000000000
APP_ID_URI=$(az ad app show --id "$CLIENT_ID" --query "identifierUris[0]" -o tsv)
APP_URL="https://$(az containerapp show --name $ACA_NAME --resource-group $ACA_RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv)"


########################################
# 1. Generate PKCE code verifier/challenge
########################################

# Create a random code verifier (hex-encoded 32 bytes => 64 characters)
CODE_VERIFIER=$(openssl rand -hex 32)

# Compute its SHA256-based code challenge using base64url (RFC 7636)
CODE_CHALLENGE=$(printf '%s' "$CODE_VERIFIER" \
 | openssl dgst -sha256 -binary \
 | openssl base64 -A \
 | tr '+/' '-_' \
 | tr -d '=')

########################################
# 2. Get authorization code interactively
########################################

# Build the authorize URL with percent-encoded spaces for scope
AUTH_URL="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/authorize?client_id=$CLIENT_ID&response_type=code&redirect_uri=http://localhost:8080/dummy&response_mode=query&scope=openid%20profile%20offline_access%20$CLIENT_ID/.default&code_challenge=$CODE_CHALLENGE&code_challenge_method=S256"

echo "Open the following URL in a browser and sign in:"
echo "$AUTH_URL"
read AUTH_CODE

########################################
# 3. Exchange code for tokens
########################################
echo $CODE_VERIFIER
TOKENS=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "grant_type=authorization_code" \
 -d "client_id=$CLIENT_ID" \
 -d "client_secret=$CLIENT_SECRET" \
 -d "code=$AUTH_CODE" \
 -d "redirect_uri=http://localhost:8080/dummy" \
 -d "code_verifier=$CODE_VERIFIER" \
 -d "scope=openid profile offline_access $CLIENT_ID/.default")
echo "$TOKENS" | jq .
# Extract the AAD tokens
ACCESS_TOKEN=$(echo "$TOKENS" | jq -r .access_token)
ID_TOKEN=$(echo "$TOKENS" | jq -r .id_token)

echo "$ID_TOKEN"
echo "$ACCESS_TOKEN"

########################################
# 3. Client-directed sign-in (Easy Auth)
########################################


LOGIN_RESPONSE=$( \
 curl -s -X POST "$APP_URL/.auth/login/aad" \
 -H "Content-Type: application/json" \
 -d "{\"access_token\":\"$ACCESS_TOKEN\",\"id_token\":\"$ID_TOKEN\"}" \
)
echo "$LOGIN_RESPONSE" | jq .
SESSION_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r .authenticationToken)

########################################
# 4. Call protected endpoint
########################################


# This is the one which proves the token store is working 
curl -s -X GET "$APP_URL$PROTECTED_ROUTE" \
 -H "X-ZUMO-AUTH: $SESSION_TOKEN"  | jq .

# Alternatively, you can use the access token directly
curl -s -X GET "$APP_URL$PROTECTED_ROUTE" \
 -H "Authorization: Bearer $ACCESS_TOKEN" | jq .

curl -i -X GET "$APP_URL$PROTECTED_ROUTE"



# DO NOT USE, JUST FOR DEMO PURPOSES

#!/bin/nothing
# ----- variables you might want to change -----
RG="rg-aks-costtest"
LOC="westeurope"
AKSNAME="aks-costtest"
AKSREGNAME="${AKSNAME}-reg"
#AKSVERSION="--kubernetes-version 1.28"   # or leave blank for default
AKSVERSION=""   # or leave blank for default
NODE_SKU="Standard_D4s_v6"
NODE_COUNT=3
WS="log-${AKSNAME}"

# ----- create resource group -----
az group create -n $RG -l $LOC

# ----- create Log Analytics workspace -----
az monitor log-analytics workspace create -g $RG -n $WS -l $LOC

WS_ID=$(az monitor log-analytics workspace show -g $RG -n $WS --query id -o tsv)

# ----- build the cost-optimised data-collection rule in-line -----
cat > dcr.json <<'EOF'
{
  "interval": "1m",
  "enableContainerLogV2": true,
  "namespaceFilteringMode": "Exclude",
  "namespaces": [ "kube-system", "gatekeeper-system", "azure-arc" ],
  "streams": [
    "Microsoft-KubePodInventory",
    "Microsoft-ContainerLogV2"
  ]
}
EOF

# ----- create AKS with monitoring enabled & custom DCR -----
az aks create \
  -g $RG -n $AKSNAME $AKSVERSION \
  --location $LOC \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SKU \
  --generate-ssh-keys \
  --enable-managed-identity \
  --enable-addons monitoring \
  --workspace-resource-id $WS_ID \
  --data-collection-settings dcr.json

az aks create \
  -g $RG -n $AKSREGNAME $AKSVERSION \
  --location $LOC \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SKU \
  --generate-ssh-keys \
  --enable-managed-identity \
  --enable-addons monitoring \
  --workspace-resource-id $WS_ID

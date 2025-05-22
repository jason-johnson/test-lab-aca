#!/bin/bash
# Information taken from https://learn.microsoft.com/en-us/cli/azure/acr/task?view=azure-cli-latest#az-acr-task-create

# Set variables
ACR_NAME="acrjbjmcap1"        # Replace with your ACR name
YAML_FILE="acr_build.yaml"

az acr task create -n acalab -r $ACR_NAME -c "https://github.com/jason-johnson/test-lab-aca.git#functions:app" -f $YAML_FILE --commit-trigger-enabled false --base-image-trigger-enabled false

az acr task run --name acalab --registry "$ACR_NAME"  --file $YAML_FILE
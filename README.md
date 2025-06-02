# ACA Testing lab

## Steps to use this repo

1. Create "manual" resource group in target subscription
2. Create storage account in "manual" resource group
3. Create ACR in "manual" resource group
4. Run the steps in `app/update_image.sh` (manually):
    - The first step creates a task in ACR for building the image
    - The second step can be used at will when ever a new (or first) version of the image is required
5. Create a project in Azure Devops
6. Set up a service connection in Azure Devops for the target Azure subscription (See [Service connection](#service-connection) below)
7. Fork this repository
8. Update `pipeline/variables.yml` to set variables to correct values
9. Create a pipeline from this repo for `pipeline/main.yml` and `pipeline/destroy.yml`
10. Run the `main` pipeline (on `functions` branch) to create the environment
11. Update `producer/.env` with the server name of the service bus namespace and the queue name you wish to target (seen in pipeline terraform apply step, but variable names need to be changed to upper case)
12. Run `producer/send.py` to send 100k messages to queue

After doing these steps, you can observe the function app or ACA scaling in response to the messages.  They both use the same image which will read the message and sleep based on the delay specified in the message.  The delays
are generated from a set of 20 possible lengths (up to 1.6 seconds) with a weight to favor quicker times more than slower ones.  The script will give some information about what it created, average delay and some sample delays.

## Service connection

If you have an existing service principal you can set up azure resource manager -> worfklow identity and manually add the federatated configuration to it.  Otherwise you can use the automatic variant which will create the service principal.

In any case, the service principal needs to have contributor on the subscription as it will be creating resources, including a new resource group.  It will also require the role "Role Based Access Control Administrator" at the subscription level so it can create RBAC roles for the various resources.

## Assumptions

This setup assumes there is a resource group, storage account and ACR that are outside the management of terraform (created in steps 1-3 above).  It will create its own resource group for all the resources for this lab.  By running `destroy.yml` all managed resources will be removed.

This setup is also completely password-less.  We use RBAC to manage authorization.

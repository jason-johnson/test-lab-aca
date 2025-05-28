# ACA Testing lab

Steps to use this repo:

1. Create ACR in target subscription
2. Run the steps in `app/update_image.sh` (manually):
    - The first step creates a task in ACR for building the image
    - The second step can be used at will when ever a new (or first) version of the image is required
3. Create a project in Azure Devops
4. Set up a service connection in Azure Devops for the target Azure subscription
5. Create a pipeline from this repo for `pipeline/main.yml` and `pipeline/destroy.yml`
6. Run the `main` pipeline (on `functions` branch) to create the environment
7. Update `producer/.env` with the server name of the service bus namespace and the queue name you wish to target
8. Run `producer/send.py` to send 100k messages to queue

After doing these steps, you can observe the function app or ACA scaling in response to the messages.  They both use the same image which will read the message and sleep based on the delay specified in the message.  The delays
are generated from a set of 20 possible lengths (up to 1.6 seconds) with a weight to favor quicker times more than slower ones.  The script will give some information about what it created, average delay and some sample delays.
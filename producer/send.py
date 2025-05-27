import asyncio
import json
import logging
import os
from azure.servicebus.aio import ServiceBusClient
from azure.servicebus import ServiceBusMessage
from azure.identity.aio import DefaultAzureCredential
from dotenv import load_dotenv
from random import choices

load_dotenv()

FULLY_QUALIFIED_NAMESPACE = os.environ["FULLY_QUALIFIED_NAMESPACE"]
QUEUE_NAME = os.environ["QUEUE_NAME"]


async def send_single_message(sender):
    # Create a Service Bus message and send it to the queue
    print("Sending a single message to the queue...")
    print("-----------------------")

    msg = json.dumps({
        "message": "This is a single message",
        "delay": 200
    })
    
    message = ServiceBusMessage(msg)
    await sender.send_messages(message)
    print("Sent a single message")


async def send_a_list_of_messages(sender):
    population = [50,   100,  150,  200,  250,  300,  350,  400,  500,  600,  700,  800,  900,  1000, 11000, 1200, 1300, 1400, 1500, 1600]
    weights =    [0.3, 0.22, 0.08, 0.1, 0.07, 0.01, 0.01, 0.01, 0.01, 0.02, 0.05, 0.03, 0.02,  0.01, 0.01,  0.01, 0.01, 0.01, 0.01, 0.01]
    print(f'Sum of weights: {sum(weights)}')
    delays = choices(population, weights, k=10**1)
    print(f'Delays: {delays[:100]}...')
    print(f'Average delay: {sum(delays) / len(delays)}')
    # Create a list of messages and send it to the queue

    messages = []
    for delay in delays:
        msg = json.dumps({
            "message": "This is a message with a delay",
            "delay": delay
        })
        messages.append(ServiceBusMessage(msg))

    await sender.send_messages(messages)
    print(f"Sent a list of {len(messages)} messages")


async def run():
    # create a Service Bus client using the credential
    print("Sending messages to the Service Bus queue...")
    print("-----------------------")
    print(f"Queue Name: {QUEUE_NAME}")
    print(f"Fully Qualified Namespace: {FULLY_QUALIFIED_NAMESPACE}")
    print("-----------------------")

    credential = DefaultAzureCredential()

    async with ServiceBusClient(
            fully_qualified_namespace=FULLY_QUALIFIED_NAMESPACE,
            credential=credential,
            logging_enable=True) as servicebus_client:
        # get a Queue Sender object to send messages to the queue
        sender = servicebus_client.get_queue_sender(queue_name=QUEUE_NAME)
        async with sender:
            # send a list of messages
            await send_a_list_of_messages(sender)

        # Close credential when no longer needed.
        await credential.close()

# logging.basicConfig(level=logging.DEBUG)

asyncio.run(run())
print("Done sending messages")
print("-----------------------")
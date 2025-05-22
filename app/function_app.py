import os
import pprint
import azure.functions as func
from sys import maxsize
import aiohttp
import datetime
import json
import logging

from azure.identity import DefaultAzureCredential

app = func.FunctionApp()

@app.service_bus_queue_trigger(
    queue_name=os.environ["QUEUE_NAME"],
    connection=os.environ["QUEUE_CONNECTION"],
    max_dequeue_count=5,
    visibility_timeout=30,
    message_encoding="base64",
)
async def sbMessage(msg: func.ServiceBusMessage) -> None:
    logging.info(f"Python ServiceBus queue trigger function processed message: {msg.get_body().decode()}")
    logging.info(f"Message ID: {msg.id}")
    logging.info(f"Message Enqueued Time: {msg.enqueued_time_utc}")
    logging.info(f"Message Dequeue Count: {msg.dequeue_count}")

@app.route(route="start")
async def hello(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Python HTTP trigger function processed a request.")
    count = req.params.get("count")
    if not count:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            count = req_body.get("count")

    return func.HttpResponse(f"Hello, {count}!") if count else func.HttpResponse(
        "Please pass a count on the query string or in the request body", status_code=400
    )
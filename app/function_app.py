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

@app.timer_trigger(schedule="0 30 9 * * 1", arg_name="syncTimer", run_on_startup=True, use_monitor=False)
async def syncAll(syncTimer: func.TimerRequest) -> None:

    if syncTimer.past_due:
        logging.info('The timer is past due!')

    credential = DefaultAzureCredential()
    client = GraphServiceClient(credentials=credential, scopes=[
                                'https://graph.microsoft.com/.default'])

    await syncGroups(client)

    logging.info('Python timer trigger function executed.')

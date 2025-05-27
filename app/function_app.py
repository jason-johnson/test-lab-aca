import json
import os
import azure.functions as func
import logging


app = func.FunctionApp()

@app.service_bus_queue_trigger(arg_name="msg", queue_name=os.environ["QUEUE_NAME"],
                               connection=os.environ["QUEUE_CONNECTION"])
async def sbMessage(msg: func.ServiceBusMessage) -> None:
    body = msg.get_body().decode()
    isJson = False

    try:
        b = json.loads(body)
        isJson = True
        body = b
    except json.JSONDecodeError:
        pass

    if isJson:
        logging.info(f"#### Python ServiceBus queue trigger function processed JSON message: {body}")
    else:
        logging.info(f"#### Python ServiceBus queue trigger function processed message: {body}")

    logging.info(f"#### Message ID: {msg.message_id}")
    logging.info(f"#### Message Enqueued Time: {msg.enqueued_time_utc}")
    logging.info(f"#### Message Content Type: {msg.content_type}")
    logging.info(f"#### Message Delivery Count: {msg.delivery_count}")
    # asyncio.sleep(5)
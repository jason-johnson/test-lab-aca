import asyncio
import json
import os
import azure.functions as func
import logging


app = func.FunctionApp()

@app.service_bus_queue_trigger(arg_name="msg", queue_name=os.environ["QUEUE_NAME"],
                               connection=os.environ["QUEUE_CONNECTION"])
async def sbMessage(msg: func.ServiceBusMessage) -> None:
    body = msg.get_body().decode()

    try:
        b = json.loads(body)
        body = b

        delay = b.get("delay", 0)
        if delay > 0:
            delay = int(delay) / 1000  # Convert milliseconds to seconds
            logging.info(f"Delaying message processing for {delay} seconds.")
            await asyncio.sleep(delay)
        else:
            logging.info("No delay specified, processing message immediately.")
    except json.JSONDecodeError:
        logging.warning("Message body is not valid JSON, processing as string.")
        return

        
    logging.info(f"#### Python ServiceBus queue trigger function processed message: {body}")
    logging.info(f"#### Message ID: {msg.message_id}")
    logging.info(f"#### Message Enqueued Time: {msg.enqueued_time_utc}")
    logging.info(f"#### Message Content Type: {msg.content_type}")
    logging.info(f"#### Message Delivery Count: {msg.delivery_count}")
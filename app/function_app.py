import os
import azure.functions as func
import logging


app = func.FunctionApp()

@app.service_bus_queue_trigger(arg_name="msg", queue_name=os.environ["QUEUE_NAME"],
                               connection=os.environ["QUEUE_CONNECTION"])
async def sbMessage(msg: func.ServiceBusMessage) -> None:
    logging.info(f"Python ServiceBus queue trigger function processed message: {msg.get_body().decode()}")
    logging.info(f"Message ID: {msg.message_id}")
    logging.info(f"Message Enqueued Time: {msg.enqueued_time_utc}")
    logging.info(f"Message Dequeue Count: {msg.dequeue_count}")
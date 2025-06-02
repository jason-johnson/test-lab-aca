import asyncio
import json
import os
import azure.functions as func
import logging


app = func.FunctionApp()


@app.service_bus_queue_trigger(arg_name="msg", queue_name=os.environ["QUEUE_NAME"],
                               connection=os.environ["QUEUE_CONNECTION"])
async def sb_message(msg: func.ServiceBusMessage) -> None:
    body = msg.get_body().decode()

    try:
        b = json.loads(body)
        body = b

        delay = b.get("delay", 0)
        if delay > 0:
            delay = int(delay) / 1000  # Convert milliseconds to seconds
            logging.info(
                f"#### Delaying message processing for {delay} seconds.")
            await asyncio.sleep(delay)
        else:
            logging.info(
                "#### No delay specified, processing message immediately.")
    except json.JSONDecodeError:
        logging.warning(
            "#### Message body is not valid JSON, processing as string.")
        return

    logging.info(
        f"#### Python ServiceBus queue trigger function processed message: {body}")
    logging.info(f"#### Message ID: {msg.message_id}")
    logging.info(f"#### Message Enqueued Time: {msg.enqueued_time_utc}")
    logging.info(f"#### Message Content Type: {msg.content_type}")
    logging.info(f"#### Message Delivery Count: {msg.delivery_count}")


@app.route(route="health_probe", auth_level=func.AuthLevel.ANONYMOUS)
def health_probe(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('#### Health Probe Triggered')
    # Always healthy as we don't do any real processing of messages
    return func.HttpResponse(
        "Healthy",
        status_code=200
    )


@app.route(route="fa_auth_test", auth_level=func.AuthLevel.FUNCTION)
def fa_auth_test(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    if name:
        return func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
             status_code=200
        )
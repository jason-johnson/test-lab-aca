import asyncio
import contextlib
import logging
import sys
from aiohttp import web

async def handle(request):
    result = {}

    for header in request.headers:
        result[header] = request.headers[header]

    return web.json_response(result)

def health_probe(req):
    logging.info('#### Health Probe Triggered')
    # Always healthy as we don't do any real processing of messages
    return web.json_response(
        "Healthy",
        status=200
    )

async def do_spam(app: web.Application):
    logging.info('#### Spammer started')
    while True:
        await asyncio.sleep(0.1)  # Simulate some delay between spam actions
        logging.info('#### Spammer is running')

async def background_tasks(app):
    app[spammer] = asyncio.create_task(do_spam(app))

    yield

    app[spammer].cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await app[spammer]

app = web.Application()
spammer = web.AppKey("spammer", asyncio.Task[None])
app.add_routes([web.get('/', handle),
                web.get('/health_probe', health_probe)])
app.cleanup_ctx.append(background_tasks)

if __name__ == '__main__':
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    web.run_app(app)
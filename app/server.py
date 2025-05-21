import asyncio
import logging
import sys
from aiohttp import web

async def handle(request):
    result = {}

    for header in request.headers:
        result[header] = request.headers[header]

    return web.json_response(result)

app = web.Application()
app.add_routes([web.get('/', handle)])

if __name__ == '__main__':
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    web.run_app(app)
import asyncio
import logging
import sys
from aiohttp import web

async def handle(request):
    name = request.match_info.get('name', "Anonymous")
    text = f"Hello, {name}"

    for header in request.headers:
        logging.info(f"Header: {header} = {request.headers[header]}")

    return web.Response(text=text)

app = web.Application()
app.add_routes([web.get('/', handle),
                web.get('/{name}', handle)])

if __name__ == '__main__':
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    web.run_app(app)
from fastapi import FastAPI
from mangum import Mangum
from mcp.server.fastmcp import FastMCP

mcp = FastMCP(name="EchoServer", stateless_http=True)

@mcp.tool(description="A simple echo tool")
def echo(message: str) -> str:
    return f"Echo: {message}"

app = FastAPI()




@app.get("/echo")
async def echo():
    return {"message": "Echo from FastAPI Lambda!"}


handler = Mangum(app)

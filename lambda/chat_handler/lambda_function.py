"""
This module contains the Lambda function handler for processing chat messages.
It integrates with an MCP (Message Control Plane) client to interact with tools
and uses a language model to generate responses.
"""

import base64
import json
import logging
import os
import time
from typing import Any, Dict

from mcp.client.streamable_http import streamablehttp_client
from strands import Agent
from strands.tools.mcp.mcp_client import MCPClient

from prompt import MAIN_PROMPT

model = os.getenv("BEDROCK_MODEL", "eu.anthropic.claude-3-7-sonnet-20250219-v1:0")

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

mcp_api_url = os.getenv("MCP_LAMBDA_API_URL")

streamable_http_mcp_client = MCPClient(lambda: streamablehttp_client(mcp_api_url))


def lambda_handler(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Lambda function to handle chat messages from authenticated users.

    Args:
        event: API Gateway event containing the request
        context: Lambda context object

    Returns:
        API Gateway response with chat reply
    """

    try:
        # Log the incoming event for debugging
        logger.info("Received event: %s", json.dumps(event, default=str))

        # Extract user information from the request context
        user_info = extract_user_info(event)

        # Extract Authorization header
        auth_header = event.get("headers", {}).get("Authorization")
        if not auth_header:
            logger.warning("Authorization header not found in the request.")
            # Depending on requirements, you might want to return an error here
            # For now, proceed without it, but the MCP call might fail.

        # Parse the request body
        body = parse_request_body(event)

        # Validate the message
        message = validate_message(body)

        with streamable_http_mcp_client:
            # Get the tools from the MCP server
            mcp_tools = streamable_http_mcp_client.list_tools_sync()

            agent = Agent(
                model=model,
                system_prompt=MAIN_PROMPT,
                tools=[mcp_tools],
            )

            # Generate a response
            response_message = agent(message)

        # Return successful response
        return create_response(
            200,
            {
                "success": True,
                "message": str(response_message),
                "timestamp": int(time.time()),
                "user": user_info.get("username", "Unknown"),
            },
        )

    except ValueError as e:
        logger.error("Validation error: %s", e)
        return create_response(400, {"success": False, "error": str(e)})

    except Exception as e:  # pylint: disable=broad-exception-caught
        logger.error("Unexpected error: %s", e)
        return create_response(
            500, {"success": False, "error": "Internal server error"}
        )


def extract_user_info(event: Dict[str, Any]) -> Dict[str, str]:
    """Extract user information from the API Gateway event."""

    # Get user info from Cognito authorizer context
    request_context = event.get("requestContext", {})
    authorizer = request_context.get("authorizer", {})

    # Extract claims from Cognito JWT
    claims = authorizer.get("claims", {})

    user_info = {
        "username": claims.get("cognito:username", "Unknown"),
        "email": claims.get("email", "unknown@example.com"),
        "sub": claims.get("sub", "unknown-sub"),
    }

    logger.info("Extracted user info: %s", user_info)
    return user_info


def parse_request_body(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parse and validate the request body."""

    body = event.get("body", "{}")

    # Handle base64 encoded body if present
    if event.get("isBase64Encoded", False):
        body = base64.b64decode(body).decode("utf-8")

    try:
        return json.loads(body)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in request body: {str(e)}") from e


def validate_message(body: Dict[str, Any]) -> str:
    """Validate the message from the request body."""

    message = body.get("message", "").strip()

    if not message:
        raise ValueError("Message cannot be empty")

    if len(message) > 1000:
        raise ValueError("Message too long (max 1000 characters)")

    return message


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a properly formatted API Gateway response."""

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": (
                "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            ),
            "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        "body": json.dumps(body),
    }

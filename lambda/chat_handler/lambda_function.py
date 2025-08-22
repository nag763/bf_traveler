import json
import logging
import os
import random
import time
from typing import Any, Dict

from prompt import MAIN_PROMPT
from strands import Agent
from tools import get_country_info

model = os.getenv("BEDROCK_MODEL", "eu.amazon.nova-pro-v1:0")

agent = Agent(
    model=model,
    system_prompt=MAIN_PROMPT,
    tools=[get_country_info],
)

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
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
        logger.info(f"Received event: {json.dumps(event, default=str)}")

        # Extract user information from the request context
        user_info = extract_user_info(event)

        # Parse the request body
        body = parse_request_body(event)

        # Validate the message
        message = validate_message(body)

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
        logger.error(f"Validation error: {str(e)}")
        return create_response(400, {"success": False, "error": str(e)})

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
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

    logger.info(f"Extracted user info: {user_info}")
    return user_info


def parse_request_body(event: Dict[str, Any]) -> Dict[str, Any]:
    """Parse and validate the request body."""

    body = event.get("body", "{}")

    # Handle base64 encoded body if present
    if event.get("isBase64Encoded", False):
        import base64

        body = base64.b64decode(body).decode("utf-8")

    try:
        return json.loads(body)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in request body: {str(e)}")


def validate_message(body: Dict[str, Any]) -> str:
    """Validate the message from the request body."""

    message = body.get("message", "").strip()

    if not message:
        raise ValueError("Message cannot be empty")

    if len(message) > 1000:
        raise ValueError("Message too long (max 1000 characters)")

    return message


def generate_chat_response(message: str, user_info: Dict[str, str]) -> str:
    """Generate a chat response based on the user's message."""

    username = user_info.get("username", "User")

    # Simple response patterns based on message content
    message_lower = message.lower()

    # Greeting responses
    if any(
        greeting in message_lower
        for greeting in [
            "hello",
            "hi",
            "hey",
            "good morning",
            "good afternoon",
            "good evening",
        ]
    ):
        responses = [
            f"Hello {username}! How can I help you today?",
            f"Hi there {username}! What's on your mind?",
            f"Hey {username}! Great to see you here!",
            f"Good to see you, {username}! How are you doing?",
        ]
        return random.choice(responses)

    # Question responses
    elif "?" in message:
        responses = [
            f"That's an interesting question, {username}! Let me think about that...",
            f"Great question! I'd say that depends on several factors, {username}.",
            f"Hmm, {username}, that's something worth exploring further!",
            f"You've got me thinking, {username}. What's your take on it?",
        ]
        return random.choice(responses)

    # Help requests
    elif any(
        help_word in message_lower
        for help_word in ["help", "assist", "support", "problem"]
    ):
        responses = [
            f"I'm here to help, {username}! What do you need assistance with?",
            f"Of course, {username}! I'd be happy to help you out.",
            f"No problem, {username}! Let me know what you're struggling with.",
            f"I'm at your service, {username}! What can I do for you?",
        ]
        return random.choice(responses)

    # Thank you responses
    elif any(thanks in message_lower for thanks in ["thank", "thanks", "appreciate"]):
        responses = [
            f"You're very welcome, {username}!",
            f"Happy to help, {username}!",
            f"Anytime, {username}! That's what I'm here for.",
            f"My pleasure, {username}!",
        ]
        return random.choice(responses)

    # Goodbye responses
    elif any(
        bye in message_lower
        for bye in ["bye", "goodbye", "see you", "farewell", "later"]
    ):
        responses = [
            f"Goodbye, {username}! Have a great day!",
            f"See you later, {username}! Take care!",
            f"Farewell, {username}! Until next time!",
            f"Bye {username}! It was great chatting with you!",
        ]
        return random.choice(responses)

    # Weather mentions
    elif any(
        weather in message_lower
        for weather in ["weather", "sunny", "rainy", "cloudy", "hot", "cold"]
    ):
        responses = [
            f"Weather can really affect our mood, can't it {username}?",
            f"I hope you're enjoying the weather today, {username}!",
            f"Weather is always a great conversation starter, {username}!",
            f"Stay comfortable out there, {username}!",
        ]
        return random.choice(responses)

    # Technology mentions
    elif any(
        tech in message_lower
        for tech in [
            "code",
            "programming",
            "software",
            "computer",
            "tech",
            "ai",
            "lambda",
        ]
    ):
        responses = [
            f"Technology is fascinating, isn't it {username}? I'm running on AWS Lambda myself!",
            f"Great to meet a fellow tech enthusiast, {username}!",
            f"The world of technology never stops evolving, {username}!",
            f"Speaking of tech, {username}, did you know this chat is powered by serverless functions?",
        ]
        return random.choice(responses)

    # Default responses
    else:
        responses = [
            f"That's interesting, {username}! Tell me more about that.",
            f"I see what you mean, {username}. What made you think of that?",
            f"Thanks for sharing that, {username}! I appreciate your perspective.",
            f"Fascinating point, {username}! I hadn't considered that angle.",
            f"You've given me something to think about, {username}!",
            f"I hear you, {username}. That's definitely worth discussing further.",
            f"Interesting observation, {username}! What's your experience with that?",
            f"That resonates with me, {username}. How do you feel about it?",
        ]
        return random.choice(responses)


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a properly formatted API Gateway response."""

    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        "body": json.dumps(body),
    }

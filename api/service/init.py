from dotenv import load_dotenv
from os import environ
from langchain_openai import AzureChatOpenAI

# Load environment variables from .env file
load_dotenv(override=False)

# Initialize the AzureChatOpenAI model
llm: AzureChatOpenAI | None = None

def initialize_llm():
    """Initialize the Azure Chat OpenAI model with specified parameters."""
    global llm
    llm = AzureChatOpenAI(
        azure_deployment="gpt-chat",  # Name of the chat model deployed in Azure OpenAI Studio
        api_version='2023-03-15-preview',  # API version for the Azure OpenAI service
        temperature=0.25,
        max_tokens=None,
        timeout=None,
        max_retries=2,
    )

# Call the initialization function
initialize_llm()

import os
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


# Azure Key Vault and Credential Setup
credential = DefaultAzureCredential()
client = SecretClient(vault_url=os.environ['KeyVaultUri'], credential=credential)

# Configure Azure OpenAI API Environment Variables
os.environ["OPENAI_API_TYPE"] = "azure_ad"
os.environ["OPENAI_API_KEY"] = credential.get_token("https://cognitiveservices.azure.com/.default").token
os.environ["AZURE_OPENAI_AD_TOKEN"] = os.environ["OPENAI_API_KEY"]

# Fetch CosmosDB Connection String from Azure Key Vault
os.environ["MONGO_CONNECTION_STRING"] = client.get_secret(os.environ['KV_CosmosDBConnectionString']).value

# Import application modules
from web import search, content
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from fastapi.logger import logger

# Configure Logging to use Gunicorn log settings, if available
gunicorn_logger = logging.getLogger('gunicorn.error')
logger.handlers = gunicorn_logger.handlers
logger.setLevel(gunicorn_logger.level)


# FastAPI Application Setup
app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(search.router)
app.include_router(content.router)




@app.get("/")
def get_status() -> str:
    """Root endpoint to check if the application is running."""
    logger.info("**Logging - RUNNING**")
    return "running"

# Run the application using Uvicorn when executed directly
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)

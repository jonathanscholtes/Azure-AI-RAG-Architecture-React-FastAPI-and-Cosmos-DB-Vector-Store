import os
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# Get the Azure Credential
credential = DefaultAzureCredential()
client = SecretClient(vault_url=os.environ['KeyVaultUri'], credential=credential)

# Set the API type to `azure_ad`
os.environ["OPENAI_API_TYPE"] = "azure_ad"
# Set the API_KEY to the token from the Azure credential
os.environ["OPENAI_API_KEY"] = credential.get_token("https://cognitiveservices.azure.com/.default").token

os.environ["AZURE_OPENAI_AD_TOKEN"] = os.environ["OPENAI_API_KEY"]

os.environ["MONGO_CONNECTION_STRING"] = client.get_secret(os.environ['KV_CosmosDBConnectionString']).value


from web import search, content
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from fastapi.logger import logger

gunicorn_logger = logging.getLogger('gunicorn.error')
logger.handlers = gunicorn_logger.handlers
logger.setLevel(gunicorn_logger.level)

app = FastAPI()


origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(search.router)
app.include_router(content.router)


@app.get("/")
def get() -> str:
    print('**RUNNING**')
    logger.info('**Logging - RUNNING**')
    return "running"


if __name__ == "__main__":
    uvicorn.run('main:app', host='0.0.0.0', port=8000)
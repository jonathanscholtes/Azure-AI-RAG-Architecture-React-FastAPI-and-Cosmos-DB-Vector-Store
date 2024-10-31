from os import environ
from dotenv import load_dotenv
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential

load_dotenv(override=True)

blob_service_client:BlobServiceClient | None = None
storage_account_container:str |None=None

def storage_init():

    credential = DefaultAzureCredential()

    AZURE_STORAGE_URL = environ.get("AZURE_STORAGE_URL")
    AZURE_STORAGE_CONTAINER = environ.get("AZURE_STORAGE_CONTAINER")
    global blob_service_client
    global storage_account_container


    storage_account_container = AZURE_STORAGE_CONTAINER
    blob_service_client =  BlobServiceClient(AZURE_STORAGE_URL, credential=credential)


storage_init()
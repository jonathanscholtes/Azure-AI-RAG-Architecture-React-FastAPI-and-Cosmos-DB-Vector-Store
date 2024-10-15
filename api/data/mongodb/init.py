from os import environ
from dotenv import load_dotenv
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores.azure_cosmos_db import AzureCosmosDBVectorSearch
from langchain_openai import AzureOpenAIEmbeddings

load_dotenv(override=False)

vector_store: AzureCosmosDBVectorSearch | None=None

def mongodb_init():
    MONGO_CONNECTION_STRING = environ.get("MONGO_CONNECTION_STRING")
    DB_NAME = "research"
    COLLECTION_NAME = "resources"
    INDEX_NAME = "vectorSearchIndex"

    global  vector_store

   
    embeddings: AzureOpenAIEmbeddings = AzureOpenAIEmbeddings(
                azure_deployment=environ.get("AZURE_OPENAI_EMBEDDING"),
                openai_api_version=environ.get("AZURE_OPENAI_API_VERSION"),
                azure_endpoint=environ.get("AZURE_OPENAI_ENDPOINT"),
                api_key=environ.get("AZURE_OPENAI_API_KEY"),)
    
    vector_store = AzureCosmosDBVectorSearch.from_connection_string(MONGO_CONNECTION_STRING,
                                                                    DB_NAME + "." + COLLECTION_NAME,
                                                                    embeddings,
                                                                    index_name=INDEX_NAME                                                                    
)
   

mongodb_init()


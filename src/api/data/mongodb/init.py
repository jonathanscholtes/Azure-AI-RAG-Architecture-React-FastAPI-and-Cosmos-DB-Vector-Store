from os import environ
from dotenv import load_dotenv
from langchain_openai import AzureOpenAIEmbeddings
from langchain_community.vectorstores.azure_cosmos_db import AzureCosmosDBVectorSearch

# Load environment variables from .env file
load_dotenv(override=False)

# Initialize vector store variable
vector_store: AzureCosmosDBVectorSearch | None = None


def mongodb_init():
    """Initialize the Azure Cosmos DB vector store."""
    mongo_connection_string = environ.get("MONGO_CONNECTION_STRING")
    db_name = "research"
    collection_name = "resources"
    index_name = "vectorSearchIndex"

    global vector_store

    # Set up embeddings using Azure OpenAI
    embeddings = AzureOpenAIEmbeddings(
        azure_deployment=environ.get("AZURE_OPENAI_EMBEDDING"),
        openai_api_version=environ.get("AZURE_OPENAI_API_VERSION"),
        azure_endpoint=environ.get("AZURE_OPENAI_ENDPOINT"),
        api_key=environ.get("AZURE_OPENAI_API_KEY"),
    )

    # Create the vector store using the connection string and embeddings
    vector_store = AzureCosmosDBVectorSearch.from_connection_string(
        mongo_connection_string,
        f"{db_name}.{collection_name}",
        embeddings,
        index_name=index_name,
    )


# Initialize MongoDB vector store
mongodb_init()

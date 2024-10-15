from os import environ
import json
from typing import List, Optional
import logging
import base64
import traceback
from pymongo.errors import ConnectionFailure
import azure.functions as func
from langchain.docstore.document import Document
from langchain.document_loaders.base import BaseLoader
from pymongo import MongoClient
from langchain_openai import AzureOpenAIEmbeddings
from langchain_community.vectorstores.azure_cosmos_db import AzureCosmosDBVectorSearch, CosmosDBSimilarityType
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient



app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.blob_trigger(arg_name="myblob", path="load", connection="AzureWebJobsStorage")
def Loader(myblob: func.InputStream):
    logging.info(f"Python blob trigger function processed blob\n"
                 f"Name: {myblob.name}\n"
                 f"Blob Size: {myblob.length} bytes")
    
    # Read the blob content
    blob_content = myblob.read()

    
    # Parse the blob content as JSON
    try:
        # Get the Azure Credential
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=environ['KeyVaultUri'], credential=credential)

        # Set the API type to `azure_ad`
        environ["OPENAI_API_TYPE"] = "azure_ad"
        # Set the API_KEY to the token from the Azure credential
        environ["OPENAI_API_KEY"] = credential.get_token("https://cognitiveservices.azure.com/.default").token

        environ["AZURE_OPENAI_AD_TOKEN"] = environ["OPENAI_API_KEY"]

        environ["MONGO_CONNECTION_STRING"] = client.get_secret(environ['KV_CosmosDBConnectionString']).value

        data = json.loads(blob_content)
        logging.info(f"Blob content as JSON: {data}")

        CosmosDBLoader(data).load()


        logging.info('** Load Images **')

        resource_id = data['resource_id']
        image_loader = BlobLoader()
        for page in data['pages']:
            
            base64_string = page['image'].replace("b'","").replace("'","")

            # Decode the Base64 string into bytes
            decoded_bytes = base64.b64decode(base64_string)

            image_loader.load_binay_data(decoded_bytes,f"{resource_id}/{page['page_id']}.png","images")

    except json.JSONDecodeError as e:
        logging.error(f"Failed to parse blob content as JSON: {e}")
        logging.error(traceback.format_exc())
    except CosmosDBLoaderException as e:
        logging.error(f"Cosmos DB loader Failed: {e}")
        logging.error(traceback.format_exc())

    

    
class CosmosDBLoaderException(Exception):
    def __init__(self, message):
        self.message = message
        super().__init__(self.message)
   
   
class JSONLoader(BaseLoader):
    def __init__(self, data: dict, content_key: Optional[str] = None):
        self.data = data
        self._content_key = content_key

    def load(self) -> List[Document]:
        
        logging.info(f"Load and return documents from the JSON file.")
        
        docs: List[Document] = []
        
        resourcetitle = self.data['title']
        resource_id = self.data['resource_id']
        pages = self.data['pages']

        for page in pages:
            page_id = page['page_id']
            text = page['body']
            chapter = page['chapter']
            pagenumber = page['page']
            metadata = {
                'resource_id': resource_id,
                'page_id': page_id,
                'title': resourcetitle,
                'chapter': chapter,
                'pagenumber': pagenumber
            }
            docs.append(Document(page_content=text, metadata=metadata))
        
        return docs
        


class CosmosDBLoader():
    def __init__(
    self,
    json_data):
        self.json_data = json_data

    def load(self):
        try:
            logging.info(f"load embeddings from file_path into cosmosDB vector store")
          


            MONGO_CONNECTION_STRING = environ.get("MONGO_CONNECTION_STRING")

            #hardcoded variables
            DB_NAME = "research"
            COLLECTION_NAME = "resources"
            INDEX_NAME = "vectorSearchIndex"

           
            client = MongoClient(MONGO_CONNECTION_STRING)

            try:

                client.admin.command('ping')
            except ConnectionFailure:
                raise CosmosDBLoaderException("Unable to reach Mongo DB Server")


            db = client[DB_NAME]
            collection = db[COLLECTION_NAME]

            loader = JSONLoader(self.json_data )

            docs = loader.load()

            logging.info(f"Create embeddings")
            embeddings: AzureOpenAIEmbeddings = AzureOpenAIEmbeddings(
                azure_deployment=environ.get("AZURE_OPENAI_EMBEDDING"),
                openai_api_version=environ.get("AZURE_OPENAI_API_VERSION"),
                azure_endpoint=environ.get("AZURE_OPENAI_ENDPOINT"),
                api_key=environ.get("AZURE_OPENAI_API_KEY"),)

            #load documents into Cosmos DB Vector Store
            logging.info(f"Create Docs: {len(docs)}")
            vector_store = AzureCosmosDBVectorSearch.from_documents(
                docs,
                embeddings,
                collection=collection,
                index_name=INDEX_NAME)        

            if vector_store.index_exists() == False:
                #Create an index for vector search
                num_lists = 1 #for a small demo, you can start with numLists set to 1 to perform a brute-force search across all vectors.
                dimensions = 1536
                similarity_algorithm = CosmosDBSimilarityType.COS

                vector_store.create_index(num_lists, dimensions, similarity_algorithm)
        except Exception as e:
                raise CosmosDBLoaderException(e)


class BlobLoader():

    def __init__(self):
        connection_string = environ.get("AZURE_STORAGE_CONNECTION_STRING")

        # Create the BlobServiceClient object        
        self.blob_service_client =  BlobServiceClient.from_connection_string(connection_string)


    def load_binay_data(self,data, blob_name:str, container_name:str):     

        blob_client = self.blob_service_client.get_blob_client(container=container_name, blob=blob_name)

        # Upload the blob data - default blob type is BlockBlob
        blob_client.upload_blob(data,overwrite=True)
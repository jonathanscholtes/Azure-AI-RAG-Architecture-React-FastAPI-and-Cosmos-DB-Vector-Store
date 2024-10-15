from dotenv import load_dotenv
from os import environ
from langchain_openai import AzureChatOpenAI
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.runnables.history import RunnableWithMessageHistory


load_dotenv(override=False)



llm: AzureChatOpenAI | None=None

def LLM_init():

    global llm

    llm = AzureChatOpenAI(
    azure_deployment="gpt-chat", ## azure_deployment: name of chat model deployed in Azure OpenAI Studio
    api_version= '2023-03-15-preview', #"2024-05-01-preview",
    temperature=.25,
    max_tokens=None,
    timeout=None,
    max_retries=2,
    )


LLM_init()
from data.mongodb import search
from .init import llm
from langchain.docstore.document import Document
from langchain.chains.combine_documents.stuff import StuffDocumentsChain
from langchain.chains.llm import LLMChain
from langchain.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
from model.airesults import AIResults
from model.resource import Resource

# Define a prompt template for the main query processing
template: str = """Use the provided context to answer the question. If the context does not contain the answer, simply state that you don’t know.
                    Your response should be informative and concise, using no more than four sentences.

                    Context: {context}

                    Question: {question}

                    Answer:"""


def get_query(query: str) -> list[Resource]:
    """Retrieve a list of resources based on the query."""
    resources, docs = search.similarity_search(query)
    return resources


def get_query_summary(query: str) -> AIResults:
    """Generate a summary for the provided query."""
    prompt_template = """Write a summary of the following:
    "{text}"
    CONCISE SUMMARY:"""
    prompt = PromptTemplate.from_template(prompt_template)

    resources, docs = search.similarity_search(query)

    if not resources:
        return AIResults(text="No Documents Found", ResourceCollection=resources)

    llm_chain = LLMChain(llm=llm, prompt=prompt)
    stuff_chain = StuffDocumentsChain(llm_chain=llm_chain, document_variable_name="text")

    summary = stuff_chain.run(docs)
    return AIResults(summary, resources)


def get_qa_from_query(query: str, logger) -> AIResults:
    """Perform a Q&A based on the provided query."""
    logger.info('** Q/A From Query **')
    resources, docs = search.similarity_search(query, logger)

    if not resources:
        return AIResults(text="No Documents Found", ResourceCollection=resources)

    custom_rag_prompt = PromptTemplate.from_template(template)

    def format_docs(docs):
        """Format document contents for the RAG chain."""
        return "\n\n".join(doc.page_content for doc in docs)

    content = format_docs(docs)

    rag_chain = (
        {"context": lambda x: content, "question": RunnablePassthrough()}
        | custom_rag_prompt
        | llm
        | StrOutputParser()
    )

    answer = rag_chain.invoke(query)
    return AIResults(text=answer, ResourceCollection=resources)

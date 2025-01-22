from model.resource import Resource
from .init import vector_store
from langchain.docstore.document import Document
from typing import List, Tuple


def results_to_model(result: Document) -> Resource:
    """Convert a Document to a Resource model."""
    return Resource(
        resource_id=result.metadata["resource_id"],
        page_id=result.metadata["page_id"],
        title=result.metadata["title"],
        source=f"{result.metadata['chapter']} (page-{result.metadata['pagenumber']})",
        content=result.page_content,
    )


def similarity_search(query: str, logger) -> Tuple[List[Resource], List[Document]]:
    """Perform a similarity search and return filtered results."""
    docs = vector_store.similarity_search_with_score(query, 6)

    # Filter documents based on cosine similarity score
    docs_filtered = [doc for doc, score in docs if score >= 0.72]

    # Log and print scores for all documents
    for doc, score in docs:
        print(score)
        logger.info(score)

    # Log the number of documents that passed the score threshold
    num_filtered = len(docs_filtered)
    print(num_filtered)
    logger.info(f'Number of documents passing score threshold: {num_filtered}')

    return [results_to_model(document) for document in docs_filtered], docs_filtered

import logging
from fastapi import APIRouter
from service import search
from model.resource import Resource
from model.airesults import AIResults
from fastapi.logger import logger

# Configure Logging to use Gunicorn log settings, if available
gunicorn_logger = logging.getLogger("gunicorn.error")
logger.handlers = gunicorn_logger.handlers
logger.setLevel(gunicorn_logger.level)

# Initialize Router with "/search" prefix
router = APIRouter(prefix="/search")

@router.get("/{query}", response_model=list[Resource])
def get_search(query: str) -> list[Resource]:
    """Retrieve a list of resources based on the search query."""
    return search.get_query(query)

@router.get("/summary/{query}", response_model=AIResults)
def get_query_summary(query: str) -> AIResults:
    """Retrieve a summarized AI response for the given query."""
    return search.get_query_summary(query)

@router.get("/qa/{query}", response_model=AIResults)
def get_query_qa(query: str) -> AIResults:
    """Retrieve a Q&A response based on the given query."""
    return search.get_qa_from_query(query, logger)

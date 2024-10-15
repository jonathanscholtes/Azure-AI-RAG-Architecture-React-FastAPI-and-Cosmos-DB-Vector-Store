from fastapi import APIRouter


from service import search as search 
from model.resource import Resource
from model.airesults import AIResults
import logging
from fastapi.logger import logger

gunicorn_logger = logging.getLogger('gunicorn.error')
logger.handlers = gunicorn_logger.handlers
logger.setLevel(gunicorn_logger.level)

router = APIRouter(prefix="/search")


@router.get("/{query}")
def get_search(query) -> list[Resource]:
    return search.get_query(query)


@router.get("/summary/{query}")
def get_query_summary(query) -> AIResults:
    return search.get_query_summary(query)


@router.get("/qa/{query}")
def get_query_qa(query) -> AIResults:
    return search.get_qa_from_query(query,logger)

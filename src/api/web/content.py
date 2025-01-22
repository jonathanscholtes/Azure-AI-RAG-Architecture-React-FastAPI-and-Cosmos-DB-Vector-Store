from fastapi import APIRouter, Response
from service import content

# Initialize Router with "/content" prefix
router = APIRouter(prefix="/content")

@router.get("/image/{resource_id}/{page_id}")
def get_image(resource_id: str, page_id: str) -> Response:
    """Retrieve image content based on resource and page IDs."""
    image_bytes = content.get_image_bytes(resource_id, page_id)
    return Response(content=image_bytes)

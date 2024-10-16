from data.storageaccount import content


def get_image_bytes(resource_id: str, page_id: str) -> bytes:
    """Retrieve image bytes for a specified resource and page."""
    blob_name = f"{resource_id}/{page_id}.png"
    return content.get_image_bytes(blob_name)

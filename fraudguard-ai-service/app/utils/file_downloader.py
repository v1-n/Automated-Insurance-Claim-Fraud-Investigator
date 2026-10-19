import logging
from dataclasses import dataclass
from typing import Optional
import httpx

logger = logging.getLogger(__name__)


@dataclass
class DownloadedFile:
    content: bytes
    file_ext: str  # 'pdf', 'png', 'jpg'
    size_bytes: int
    content_type: str


async def download_file(
    url: str,
    item_tag: str = "File",
    client: Optional[httpx.AsyncClient] = None,
    timeout: float = 25.0,
) -> DownloadedFile:
    """
    Downloads a file asynchronously from Cloudinary or any public HTTP/HTTPS URL into memory.
    Detects file extension using magic bytes, Content-Type headers, and URL endings.
    """
    logger.info(f"[{item_tag}] Initiating download from URL: {url[:70]}...")

    async def _fetch(c: httpx.AsyncClient) -> httpx.Response:
        res = await c.get(url, timeout=timeout)
        res.raise_for_status()
        return res

    if client:
        res = await _fetch(client)
    else:
        async with httpx.AsyncClient() as new_client:
            res = await _fetch(new_client)

    raw_file = res.content
    content_type = res.headers.get("content-type", "").lower()

    # Detect file type using magic bytes, content-type headers, and URL extension
    if raw_file.startswith(b"%PDF") or "pdf" in content_type or url.lower().endswith(".pdf"):
        file_ext = "pdf"
    elif raw_file.startswith(b"\x89PNG") or "png" in content_type or url.lower().endswith(".png"):
        file_ext = "png"
    elif raw_file.startswith(b"\xff\xd8\xff") or "jpeg" in content_type or "jpg" in content_type or url.lower().endswith((".jpg", ".jpeg")):
        file_ext = "jpg"
    else:
        file_ext = "jpg"  # Default fallback for images

    logger.info(f"[{item_tag}] Download complete ({len(raw_file)} bytes, detected format: {file_ext})")

    return DownloadedFile(
        content=raw_file,
        file_ext=file_ext,
        size_bytes=len(raw_file),
        content_type=content_type,
    )

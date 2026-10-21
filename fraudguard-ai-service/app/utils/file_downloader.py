import logging
from dataclasses import dataclass
from typing import Optional
from urllib.parse import urlparse
import httpx

logger = logging.getLogger(__name__)

# Security: Only allow downloads from trusted hosts
ALLOWED_HOSTS = [
    "res.cloudinary.com",
    "cloudinary.com",
]

# Maximum allowed download size: 25 MB
MAX_DOWNLOAD_SIZE_BYTES = 25 * 1024 * 1024


@dataclass
class DownloadedFile:
    content: bytes
    file_ext: str  # 'pdf', 'png', 'jpg'
    size_bytes: int
    content_type: str


def _validate_url(url: str) -> None:
    """Validates that the URL uses HTTPS and belongs to an allowed host."""
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise ValueError(f"Invalid URL scheme: {parsed.scheme}. Only HTTPS is allowed.")
    if parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError(
            f"Host '{parsed.hostname}' is not in the allowed list. "
            f"Only downloads from {ALLOWED_HOSTS} are permitted."
        )


async def download_file(
    url: str,
    item_tag: str = "File",
    client: Optional[httpx.AsyncClient] = None,
    timeout: float = 25.0,
) -> DownloadedFile:
    """
    Downloads a file asynchronously from Cloudinary or any allowed public HTTPS URL.
    Streams the response and enforces a byte cap to prevent OOM on large files.
    Validates host allowlist and rejects non-HTTPS URLs.
    Redirects are disabled to prevent SSRF via open redirect chains.
    """
    _validate_url(url)
    logger.info(f"[{item_tag}] Initiating download from URL: {url[:70]}...")

    async def _stream_download(c: httpx.AsyncClient) -> tuple[bytes, str]:
        """Streams the response body and enforces MAX_DOWNLOAD_SIZE_BYTES."""
        async with c.stream("GET", url, timeout=timeout, follow_redirects=False) as response:
            response.raise_for_status()
            content_type = response.headers.get("content-type", "").lower()

            chunks = []
            total_bytes = 0
            async for chunk in response.aiter_bytes(chunk_size=65_536):
                total_bytes += len(chunk)
                if total_bytes > MAX_DOWNLOAD_SIZE_BYTES:
                    raise ValueError(
                        f"File exceeds maximum allowed size "
                        f"({MAX_DOWNLOAD_SIZE_BYTES / (1024 * 1024):.0f} MB). "
                        f"Download aborted at {total_bytes / (1024 * 1024):.1f} MB."
                    )
                chunks.append(chunk)

            return b"".join(chunks), content_type

    if client:
        raw_file, content_type = await _stream_download(client)
    else:
        async with httpx.AsyncClient() as new_client:
            raw_file, content_type = await _stream_download(new_client)

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

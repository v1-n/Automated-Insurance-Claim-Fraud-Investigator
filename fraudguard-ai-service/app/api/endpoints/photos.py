import io
import logging
from datetime import datetime
import exifread
from fastapi import APIRouter, HTTPException
import httpx
import imagehash
from PIL import Image

from app.enums.severity import Severity
from app.enums.verification_status import VerificationStatus
from app.models.photo_inspect_request import PhotoInspectRequest
from app.models.photo_inspect_response import (
    PhotoForensicDetails,
    PhotoFlag,
    PhotoInspectResponse,
)
from app.utils.file_downloader import download_file

logger = logging.getLogger(__name__)
router = APIRouter()


def convert_to_degrees(value) -> float | None:
    """Helper to convert the GPS ratio lists into a single float degree."""
    if not value or len(value) < 3:
        return None
    try:
        d = float(value[0])
        m = float(value[1])
        s = float(value[2])
        return d + (m / 60.0) + (s / 3600.0)
    except Exception:
        return None


async def download_and_phash(client: httpx.AsyncClient, photo_id: int, url: str) -> tuple[bytes, str]:
    """Downloads photo into memory and calculates 64-bit perceptual hash."""
    downloaded = await download_file(url, item_tag=f"Photo #{photo_id}", client=client)
    img = Image.open(io.BytesIO(downloaded.content))
    # Using perceptual hash (pHash) which is robust to resizing and minor edits
    phash_val = str(imagehash.phash(img))
    return downloaded.content, phash_val


@router.post("/inspect-photo", response_model=PhotoInspectResponse)
async def inspect_photo(payload: PhotoInspectRequest):
    logger.info(
        f"[{payload.tenant_id}] Received photo inspection request for Claim #{payload.claim_id}, Photo #{payload.photo_id}"
    )

    try:
        async with httpx.AsyncClient() as client:
            raw_file, phash_val = await download_and_phash(client, payload.photo_id, payload.photo_url)
    except Exception as e:
        logger.error(f"[Photo #{payload.photo_id}] Failed to download or process image: {str(e)}", exc_info=True)
        raise HTTPException(status_code=400, detail=f"Failed to process image from URL: {str(e)}")

    # Extract EXIF metadata using exifread
    file_handle = io.BytesIO(raw_file)
    tags = exifread.process_file(file_handle, details=False)

    exif_found = bool(tags)
    is_manipulated = False
    flags: list[PhotoFlag] = []

    # 1. Camera details
    camera_make = str(tags.get("Image Make")) if tags.get("Image Make") else None
    camera_model = str(tags.get("Image Model")) if tags.get("Image Model") else None

    # 2. Capture Date
    photo_date_tag = tags.get("EXIF DateTimeOriginal") or tags.get("Image DateTime")
    captured_at = str(photo_date_tag) if photo_date_tag else None

    # 3. Software tag check
    software_tag = str(tags.get("Image Software")) if tags.get("Image Software") else None
    if software_tag:
        suspicious_software = ["photoshop", "gimp", "canva", "picsart", "lightroom", "snapseed"]
        if any(tool in software_tag.lower() for tool in suspicious_software):
            is_manipulated = True
            flags.append(
                PhotoFlag(
                    code="PHOTO_EDITING_SOFTWARE_DETECTED",
                    severity=Severity.MEDIUM,
                    explanation=f"Image metadata indicates manipulation with editing software: {software_tag}.",
                    benignExplanations=["User cropped, compressed, or resized image before uploading"],
                    nextSteps=["Request original, unedited photo directly from device gallery"],
                )
            )

    # 4. Check capture date vs claimed incident date
    if captured_at:
        try:
            # EXIF datetime format: "YYYY:MM:DD HH:MM:SS"
            photo_dt = datetime.strptime(captured_at.strip(), "%Y:%m:%d %H:%M:%S")

            incident_dt = payload.incident_context.incident_date
            if not isinstance(incident_dt, datetime):
                incident_dt = datetime.combine(incident_dt, datetime.min.time())

            # Direction A: Photo was captured before the claimed accident date (pre-existing damage)
            if (incident_dt - photo_dt).total_seconds() > 86400:
                flags.append(
                    PhotoFlag(
                        code="PHOTO_TAKEN_PRIOR_TO_INCIDENT",
                        severity=Severity.HIGH,
                        explanation=(
                            f"Photo capture date ({photo_dt.strftime('%Y-%m-%d')}) is older than "
                            f"claimed incident date ({incident_dt.strftime('%Y-%m-%d')})."
                        ),
                        benignExplanations=["Phone device clock/calendar was misconfigured"],
                        nextSteps=["Inspect phone camera roll or request live in-app inspection photo"],
                    )
                )
            # Direction B: Photo was captured long after claimed incident date (>30 days delay)
            elif (photo_dt - incident_dt).total_seconds() > (30 * 86400):
                delay_days = int((photo_dt - incident_dt).total_seconds() // 86400)
                flags.append(
                    PhotoFlag(
                        code="PHOTO_SIGNIFICANT_CAPTURE_DELAY",
                        severity=Severity.MEDIUM,
                        explanation=(
                            f"Photo capture date ({photo_dt.strftime('%Y-%m-%d')}) is {delay_days} days "
                            f"after the claimed incident date ({incident_dt.strftime('%Y-%m-%d')})."
                        ),
                        benignExplanations=["Customer delayed taking evidence photos until repair surveyor visit"],
                        nextSteps=["Verify reason for delayed damage photo capture"],
                    )
                )
        except Exception as e:
            logger.debug(f"[Photo #{payload.photo_id}] Could not parse EXIF datetime '{captured_at}': {e}")

    # 5. Extract GPS Latitude & Longitude if present
    gps_latitude = None
    gps_longitude = None
    lat_tag = tags.get("GPS GPSLatitude")
    lat_ref = tags.get("GPS GPSLatitudeRef")
    lon_tag = tags.get("GPS GPSLongitude")
    lon_ref = tags.get("GPS GPSLongitudeRef")

    if lat_tag and lat_ref:
        gps_latitude = convert_to_degrees(lat_tag.values)
        if str(lat_ref).strip().upper() == "S" and gps_latitude is not None:
            gps_latitude = -gps_latitude

    if lon_tag and lon_ref:
        gps_longitude = convert_to_degrees(lon_tag.values)
        if str(lon_ref).strip().upper() == "W" and gps_longitude is not None:
            gps_longitude = -gps_longitude

    forensic_details = PhotoForensicDetails(
        camera_make=camera_make,
        camera_model=camera_model,
        captured_at=captured_at,
        software_tag=software_tag,
        gps_latitude=gps_latitude,
        gps_longitude=gps_longitude,
    )

    status = (
        VerificationStatus.SUSPICIOUS
        if any(f.severity == Severity.HIGH for f in flags)
        else VerificationStatus.PASSED
    )

    summary = (
        f"Photo #{payload.photo_id} analyzed (pHash: {phash_val}). Generated {len(flags)} forensic flag(s)."
    )
    logger.info(
        f"[{payload.tenant_id}] Finished Photo #{payload.photo_id} inspection: Status={status}, Flags={len(flags)}"
    )

    return PhotoInspectResponse(
        photo_id=payload.photo_id,
        phash=phash_val,
        exif_found=exif_found,
        is_manipulated=is_manipulated,
        forensic_details=forensic_details,
        flags=flags,
        verification_status=status,
        summary=summary,
    )

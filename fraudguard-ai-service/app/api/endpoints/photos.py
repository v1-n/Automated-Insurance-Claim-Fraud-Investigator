import io
import logging
import math
from datetime import date, datetime
from zoneinfo import ZoneInfo
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

# Maximum allowed image size: 15 MB
MAX_PHOTO_SIZE_BYTES = 15 * 1024 * 1024

# Perceptual hash Hamming distance thresholds:
# 0 = exact duplicate
# <= 5 = near duplicate (crop, recompress, resize, watermark)
DUPLICATE_EXACT_DISTANCE = 0
DUPLICATE_SIMILAR_DISTANCE = 5

# GPS Distance Thresholds (km)
GPS_PROXIMITY_KM = 50.0  # Within 50km is considered consistent/acceptable for city perimeter


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


def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance between two GPS coordinates in kilometers."""
    R = 6371.0  # Earth's radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2.0) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


async def download_and_phash(client: httpx.AsyncClient, photo_id: int, url: str) -> tuple[bytes, str, imagehash.ImageHash]:
    """Downloads photo into memory and calculates 64-bit perceptual hash."""
    downloaded = await download_file(url, item_tag=f"Photo #{photo_id}", client=client)

    # Enforce file size limit
    if downloaded.size_bytes > MAX_PHOTO_SIZE_BYTES:
        raise ValueError(
            f"Photo size ({downloaded.size_bytes / (1024 * 1024):.1f} MB) exceeds "
            f"maximum allowed size ({MAX_PHOTO_SIZE_BYTES / (1024 * 1024):.0f} MB)"
        )

    img = Image.open(io.BytesIO(downloaded.content))
    # Using perceptual hash (pHash) which is robust to resizing and minor edits
    phash_obj = imagehash.phash(img)
    phash_val = str(phash_obj)
    return downloaded.content, phash_val, phash_obj


def determine_photo_status(flags: list[PhotoFlag], exif_found: bool) -> VerificationStatus:
    """Determines the verification status based on flags and EXIF presence."""
    if any(f.severity == Severity.HIGH for f in flags):
        return VerificationStatus.SUSPICIOUS
    elif not exif_found:
        return VerificationStatus.UNVERIFIABLE
    elif any(f.severity == Severity.MEDIUM for f in flags):
        return VerificationStatus.SUSPICIOUS
    else:
        return VerificationStatus.PASSED


@router.post("/inspect-photo", response_model=PhotoInspectResponse)
async def inspect_photo(payload: PhotoInspectRequest):
    logger.info(
        f"[{payload.tenant_id}] Received photo inspection request for Claim #{payload.claim_id}, Photo #{payload.photo_id}"
    )

    try:
        async with httpx.AsyncClient() as client:
            raw_file, phash_val, phash_obj = await download_and_phash(client, payload.photo_id, payload.photo_url)
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

    # Normalize incident date to a timezone-naive date object using IST
    ist = ZoneInfo("Asia/Kolkata")
    today_ist = datetime.now(ist).date()
    incident_val = payload.incident_context.incident_date
    if isinstance(incident_val, datetime):
        # Convert timezone-aware to naive date safely
        incident_date = incident_val.date()
    elif isinstance(incident_val, date):
        incident_date = incident_val
    else:
        incident_date = today_ist

    # 4. Check capture date vs claimed incident date (Graduated Tolerance Rules)
    if captured_at:
        try:
            # Standard EXIF datetime format: "YYYY:MM:DD HH:MM:SS"
            clean_date_str = captured_at.strip()
            photo_dt = datetime.strptime(clean_date_str[:19], "%Y:%m:%d %H:%M:%S")
            photo_date = photo_dt.date()
            day_diff = (photo_date - incident_date).days

            if day_diff < 0:
                # Photo was taken BEFORE the accident occurred (pre-existing damage)
                days_prior = abs(day_diff)
                flags.append(
                    PhotoFlag(
                        code="PHOTO_TAKEN_PRIOR_TO_INCIDENT",
                        severity=Severity.HIGH,
                        explanation=(
                            f"Photo capture date ({photo_date}) is {days_prior} day(s) before "
                            f"the claimed incident date ({incident_date}). Possible pre-existing damage."
                        ),
                        benignExplanations=["Phone device clock/calendar was misconfigured"],
                        nextSteps=["Inspect phone camera roll or request live in-app inspection photo"],
                    )
                )
            elif day_diff == 0:
                # Same calendar day -> legitimate, no mismatch flag raised
                logger.info(f"[Photo #{payload.photo_id}] Photo capture date matches incident date ({photo_date})")
            elif day_diff == 1:
                # 1 day later -> LOW severity review flag (normal for next-day reporting)
                flags.append(
                    PhotoFlag(
                        code="PHOTO_INCIDENT_DATE_MISMATCH_MINOR",
                        severity=Severity.LOW,
                        explanation=(
                            f"Photo was taken 1 day after the claimed incident "
                            f"(Incident: {incident_date}, Photo: {photo_date})."
                        ),
                        benignExplanations=["Customer took accident photo the morning after the incident"],
                        nextSteps=["Verify timeline during claim intake call; no special escalation required"],
                    )
                )
            elif 2 <= day_diff <= 7:
                # 2 to 7 days later -> MEDIUM severity review flag
                flags.append(
                    PhotoFlag(
                        code="PHOTO_INCIDENT_DATE_MISMATCH_MODERATE",
                        severity=Severity.MEDIUM,
                        explanation=(
                            f"Photo was taken {day_diff} days after the claimed incident "
                            f"(Incident: {incident_date}, Photo: {photo_date})."
                        ),
                        benignExplanations=["Customer delayed photographing damage until surveyor visited"],
                        nextSteps=["Surveyor to confirm vehicle was stationary and not driven during the delay"],
                    )
                )
            else:
                # > 7 days later -> HIGH severity review flag
                flags.append(
                    PhotoFlag(
                        code="PHOTO_SIGNIFICANT_CAPTURE_DELAY",
                        severity=Severity.HIGH,
                        explanation=(
                            f"Photo was taken {day_diff} days after the claimed incident "
                            f"(Incident: {incident_date}, Photo: {photo_date}). Significant delay in evidence capture."
                        ),
                        benignExplanations=["Extended hospitalization or dispute before claim filing"],
                        nextSteps=["Investigate reasons for prolonged delay; check towing records and repair estimates"],
                    )
                )
        except Exception as e:
            logger.warning(f"[Photo #{payload.photo_id}] Malformed or unparseable EXIF datetime '{captured_at}': {e}")
            flags.append(
                PhotoFlag(
                    code="PHOTO_EXIF_DATE_CORRUPTED",
                    severity=Severity.MEDIUM,
                    explanation=(
                        f"Photo contains EXIF date tag '{captured_at}', but it could not be parsed as a valid datetime. "
                        "Date verification is inconclusive."
                    ),
                    benignExplanations=["Camera firmware wrote non-standard date format"],
                    nextSteps=["Inspect physical phone file details or request raw uncompressed photo"],
                )
            )
    elif exif_found and not captured_at:
        # Camera metadata exists (e.g. make/model), but DateTimeOriginal is absent
        flags.append(
            PhotoFlag(
                code="PHOTO_CAPTURE_DATE_UNAVAILABLE",
                severity=Severity.LOW,
                explanation="Photo contains camera metadata, but no timestamp or capture date was recorded by the device.",
                benignExplanations=["Camera app privacy setting disabled saving capture time"],
                nextSteps=["Verify incident date against repair estimate or workshop intake receipt"],
            )
        )

    # 5. FLAG: Missing EXIF metadata entirely
    if not exif_found:
        flags.append(
            PhotoFlag(
                code="PHOTO_NO_EXIF_METADATA",
                severity=Severity.MEDIUM,
                explanation=(
                    "Photo contains no EXIF metadata (no camera info, no capture date, no GPS). "
                    "Capture date and camera authenticity verification is unavailable."
                ),
                benignExplanations=[
                    "Image was sent via WhatsApp, Telegram, or downloaded from a web portal which strips EXIF",
                    "Uploaded as a screenshot or saved via social media",
                ],
                nextSteps=[
                    "Request original, uncompressed photo directly from device gallery",
                    "Conduct physical survey if damage severity is high",
                ],
            )
        )

    # 6. Extract GPS Latitude & Longitude if present
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

    # 6b. Compare Photo GPS with Claim Incident Location (if both are provided)
    inc_lat = payload.incident_context.incident_latitude
    inc_lon = payload.incident_context.incident_longitude

    if gps_latitude is not None and gps_longitude is not None:
        if inc_lat is not None and inc_lon is not None and (inc_lat != 0.0 or inc_lon != 0.0):
            distance_km = calculate_haversine_distance(gps_latitude, gps_longitude, inc_lat, inc_lon)
            if distance_km > GPS_PROXIMITY_KM:
                flags.append(
                    PhotoFlag(
                        code="PHOTO_LOCATION_MISMATCH",
                        severity=Severity.HIGH,
                        explanation=(
                            f"Photo GPS coordinates ({gps_latitude:.4f}, {gps_longitude:.4f}) are "
                            f"{distance_km:.1f} km away from claimed incident location "
                            f"({inc_lat:.4f}, {inc_lon:.4f}), exceeding {GPS_PROXIMITY_KM} km limit."
                        ),
                        benignExplanations=[
                            "Vehicle was towed to a garage or residence in a different city before photo was taken",
                            "Claimant entered inaccurate incident coordinates",
                        ],
                        nextSteps=[
                            "Cross-reference towing receipts or workshop job card address",
                            "Ask surveyor to verify location where vehicle is currently parked",
                        ],
                    )
                )
            else:
                logger.info(
                    f"[Photo #{payload.photo_id}] Photo GPS matches incident location (Distance: {distance_km:.1f} km)"
                )
    elif exif_found and (gps_latitude is None or gps_longitude is None):
        # Camera has EXIF but GPS location was turned off
        logger.info(f"[Photo #{payload.photo_id}] Photo has EXIF but no GPS coordinates (location services disabled)")

    # 7. Cross-Claim Perceptual Hash Duplicate Detection
    if payload.existing_hashes:
        for past_hash_str in payload.existing_hashes:
            cleaned_hash = past_hash_str.strip().lower()
            # A 64-bit perceptual hash is always exactly 16 hexadecimal characters
            if len(cleaned_hash) != 16 or not all(c in "0123456789abcdef" for c in cleaned_hash):
                logger.warning(
                    f"[Photo #{payload.photo_id}] Skipping invalid historical pHash '{past_hash_str}'. "
                    f"Expected 16 hex chars, got {len(cleaned_hash)}."
                )
                continue

            try:
                past_hash = imagehash.hex_to_hash(cleaned_hash)
                hamming_dist = phash_obj - past_hash  # calculates bit differences

                if hamming_dist == DUPLICATE_EXACT_DISTANCE:
                    flags.append(
                        PhotoFlag(
                            code="PHOTO_EXACT_DUPLICATE_DETECTED",
                            severity=Severity.HIGH,
                            explanation=(
                                f"Photo is an EXACT duplicate of an image from another claim "
                                f"(pHash: {cleaned_hash}, Hamming distance: 0)."
                            ),
                            benignExplanations=["Duplicate document uploaded twice by mistake in the same claim file"],
                            nextSteps=["Check claim history for the matching claim ID; flag for SIU investigation"],
                        )
                    )
                    break
                elif hamming_dist <= DUPLICATE_SIMILAR_DISTANCE:
                    flags.append(
                        PhotoFlag(
                            code="PHOTO_PERCEPTUAL_NEAR_DUPLICATE",
                            severity=Severity.HIGH,
                            explanation=(
                                f"Photo is visually nearly identical to a photo from a previous claim "
                                f"(pHash: {cleaned_hash}, Hamming distance: {hamming_dist} <= {DUPLICATE_SIMILAR_DISTANCE}). "
                                "Possible re-used or slightly cropped/resized accident photo."
                            ),
                            benignExplanations=["Same vehicle photographed at slightly different angles or re-saved"],
                            nextSteps=["Side-by-side comparison with historical claim photo by investigator"],
                        )
                    )
                    break
            except Exception as e:
                logger.warning(f"[Photo #{payload.photo_id}] Error comparing past pHash '{past_hash_str}': {e}")

    forensic_details = PhotoForensicDetails(
        camera_make=camera_make,
        camera_model=camera_model,
        captured_at=captured_at,
        software_tag=software_tag,
        gps_latitude=gps_latitude,
        gps_longitude=gps_longitude,
    )

    status = determine_photo_status(flags, exif_found)

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

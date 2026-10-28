from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from aioboto3 import Session
from types_aiobotocore_s3 import S3Client

from app.core.config import settings


@asynccontextmanager
async def s3_client() -> AsyncIterator[S3Client]:
    session = Session()
    async with session.client(
        "s3",
        endpoint_url=settings.s3.endpoint_url,
        region_name=settings.s3.region,
        aws_access_key_id=settings.s3.access_key_id,
        aws_secret_access_key=settings.s3.secret_access_key.get_secret_value(),
    ) as s3:
        yield s3

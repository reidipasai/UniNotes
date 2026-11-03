import datetime
import pytz
import os
from pathlib import Path

from fastapi import APIRouter, HTTPException, Body, File, UploadFile, Form
from fastapi.responses import JSONResponse

from database.models.models import MediaFile

router = APIRouter()


@router.post("/upload") # type: ignore
async def upload_file(
    file: UploadFile = File(...),
    user: str = Form(...),
    channel: str = Form(...),
    file_type: str = Form(...),
) -> JSONResponse:
    try:
        latest_file = MediaFile.objects(
            channel=channel,
            file_type=file_type,
        ).order_by('-file_no').first()

        file_no = 1 if latest_file is None else latest_file.file_no + 1

        file_dir = f"uploads/{file_type.lower()}_files/{channel}"
        os.makedirs(file_dir, exist_ok=True)

        if file_type == "PDF":
            file_extension = ".pdf"
        elif file_type == "MP3":
            file_extension = ".mp3"
        elif file_type == "M4A":
            file_extension = ".m4a"
        else:
            raise HTTPException(status_code=400, detail="Unsupported file type")
        
        filename = f"{user}_{channel}_{file_no}{file_extension}"
        filepath = f"{file_dir}/{filename}"

        with open(filepath, "wb") as buffer:
            content = await file.read()
            buffer.write(content)

        MediaFile(
            user=user,
            filepath=filepath,
            channel=channel,
            file_no=file_no,
            file_type=file_type,
        ).save()

        return JSONResponse(
            status_code=201, 
            content={
                "filepath": filepath,
                "filename": filename,
                "file_no": file_no
            }
        )
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/MediaFile") # type: ignore
async def add_media_file(
    user: str = Body(...),
    filepath: str = Body(...),
    channel: str = Body(...),
    file_no: int = Body(...),
    file_type: str = Body(...),
) -> JSONResponse:
    try:
        MediaFile(
            user=user,
            filepath=filepath,
            channel=channel,
            file_no=file_no,
            file_type=file_type,
        ).save()

        return JSONResponse(status_code=201, content={})
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/MediaFile") # type: ignore
async def fetch_media_file(
    channel: str = Body(...),
    file_no: int = Body(...),
    file_type: str = Body(...),
) -> JSONResponse:
    try:

        file = MediaFile.objects(
            channel=channel,
            file_no=file_no,
            file_type=file_type,
        ).first()

        if file is None:
            raise HTTPException(status_code=404, detail="File not found")

        return JSONResponse(
            status_code=200,
            content={
                "filepath": file.filepath,
            }
        )

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


import traceback

@router.post("/MediaFiles/channel")  # type: ignore
async def fetch_channel_files(
    channel: str = Body(...),
    file_type: str = Body(...),
) -> JSONResponse:
    try:
        files = MediaFile.objects(
            channel=channel,
            file_type=file_type,
        ).order_by('-uploaded_at')

        files_data = []
        for file in files:
            uploaded_at_str = (
                file.uploaded_at.strftime("%Y-%m-%d %H:%M:%S")
                if file.uploaded_at else None
            )
            filename = (
                file.filepath.split('/')[-1]
                if file.filepath else None
            )
            files_data.append({
                "user": file.user,
                "filepath": file.filepath,
                "file_no": file.file_no,
                "uploaded_at": uploaded_at_str,
                "filename": filename,
                "likes": len(file.likes) if file.likes else 0,
                "liked_by": file.likes or [],
            })

        return JSONResponse(
            status_code=200,
            content={"files": files_data}
        )

    except Exception as e:
        print("❌ ERROR in /MediaFiles/channel:", e)
        traceback.print_exc()   # 👈 print full stacktrace in console
        raise HTTPException(status_code=500, detail=f"Error in fetch_channel_files: {e}")


@router.post("/MediaFiles/next-number") # type: ignore
async def get_next_file_number(
    channel: str = Body(...),
    file_type: str = Body(...),
) -> JSONResponse:
    try:
        latest_file = MediaFile.objects(
            channel=channel,
            file_type=file_type,
        ).order_by('-file_no').first()

        next_number = 1 if latest_file is None else latest_file.file_no + 1

        return JSONResponse(
            status_code=200,
            content={"next_number": next_number}
        )

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

@router.post("/MediaFiles/toggle-like")  # type: ignore
async def toggle_like(
    channel: str = Body(...),
    file_no: int = Body(...),
    file_type: str = Body(...),
    username: str = Body(...),
) -> JSONResponse:
    try:
        file = MediaFile.objects(
            channel=channel,
            file_no=file_no,
            file_type=file_type,
        ).first()

        if not file:
            raise HTTPException(status_code=404, detail="File not found")

        if username in file.likes:
            file.likes.remove(username)  # 👈 unlike
        else:
            file.likes.append(username)  # 👈 like

        file.save()

        return JSONResponse(
            status_code=200,
            content={
                "likes": len(file.likes),
                "liked": username in file.likes  # whether current user liked it
            }
        )

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

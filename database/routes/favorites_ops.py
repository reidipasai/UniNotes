from fastapi import APIRouter, HTTPException, Body
from fastapi.responses import JSONResponse
from mongoengine import DoesNotExist
from database.models.models import User

router = APIRouter()

@router.post("/toggle")  # type: ignore
async def toggle_favorite(
    username: str = Body(...),
    lesson_name: str = Body(...),
) -> JSONResponse:
    try:
        user = User.objects(username=username).first()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")

        if lesson_name in user.favorites:
            user.favorites.remove(lesson_name)
            user.save()
            return JSONResponse(
                status_code=200,
                content={
                    "status": "removed",
                    "favorites": user.favorites,
                },
            )
        else:
            user.favorites.append(lesson_name)
            user.save()
            return JSONResponse(
                status_code=200,
                content={
                    "status": "added",
                    "favorites": user.favorites,
                },
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/list")
async def list_favorites(payload: dict = Body(...)):
    username = payload.get("username")
    if not username:
        raise HTTPException(status_code=400, detail="Username is required")

    user = User.objects(username=username).first()
    if not user:
        return {"favorites": []}

    return {"favorites": user.favorites}


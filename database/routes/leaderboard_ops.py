from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from database.models.models import MediaFile, User

router = APIRouter()

@router.get("/leaderboard")
async def get_leaderboard() -> JSONResponse:
    try:
        # Aggregate likes per user
        users_likes = {}
        for file in MediaFile.objects():
            like_count = len(file.likes) if file.likes else 0
            if file.user not in users_likes:
                users_likes[file.user] = 0
            users_likes[file.user] += like_count

        # Attach emails
        leaderboard = []
        for username, total_likes in users_likes.items():
            user = User.objects(username=username).first()
            if user:
                leaderboard.append({
                    "username": user.username,
                    "email": user.email,
                    "likes": total_likes,
                })

        # Sort descending by likes
        leaderboard.sort(key=lambda x: x["likes"], reverse=True)

        return JSONResponse(status_code=200, content={"leaderboard": leaderboard})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

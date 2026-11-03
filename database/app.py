import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from database.routes.user_management import router as UserManagement
from database.routes.chat_ops import router as ChatOps
from database.routes.file_ops import router as FileOps
from database.routes.favorites_ops import router as FavoritesOps
from database.routes.leaderboard_ops import router as LeaderboardOps
from database.utils import initialize_db


app = FastAPI()

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# CORS middleware (place this before including routers)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins (for development only)
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

@app.on_event("startup")  # type: ignore
async def start_database() -> None:
    initialize_db()

app.include_router(UserManagement, prefix="/user_management")
app.include_router(ChatOps, prefix="/chat")
app.include_router(FileOps, prefix="/files")
app.include_router(FavoritesOps, prefix="/favorites")
app.include_router(LeaderboardOps, prefix="/leaderboard")

if __name__ == "__main__":
    # Use 0.0.0.0 to allow connections from other devices on the same network
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True, log_level="debug")

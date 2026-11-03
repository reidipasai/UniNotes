import os

from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.responses import JSONResponse, Response
from fastapi.security import OAuth2PasswordBearer
from itsdangerous import URLSafeTimedSerializer
from werkzeug.security import check_password_hash, generate_password_hash

from database.models.models import Session, User

router = APIRouter()
SECRET_KEY = os.getenv("SECRET_KEY", "mysecretkey")
serializer = URLSafeTimedSerializer(SECRET_KEY)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

@router.post("/login") # type: ignore
async def login(
    username: str = Body(...), 
    password: str = Body(...),
) -> JSONResponse:
    """
    Authenticate a user based on their user ID, password
    If the user is already logged in or credentials are invalid, appropriate errors are raised.

    :param user_data: User login information (user ID, password)
    :type user_data: BaseModel (see model.py)
    """
    try:
        user = User.objects(username=username).first()
        if not user or not check_password_hash(user.password, password):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        if Session.objects(username=user.username).first():
            raise HTTPException(status_code=402, detail="Already logged in")

        token = str(serializer.dumps(user.username))
        Session(token=token, username=user.username).save()

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "token": token,
                "username": user.username,
                "email": user.email,
            },
        )
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/logout")  # type: ignore
async def logout(token: str = Depends(oauth2_scheme)) -> Response:
    """
    Log out a user based on the authentication token.
    Deletes the corresponding session if the token is valid.

    :param token: Bearer token used for authenticating the session
    :type token: str (provided via OAuth2 scheme)
    """
    if not token:
        raise HTTPException(status_code=400, detail="Token missing")

    try:
        session = Session.objects(token=token).first()
        if not session:
            raise HTTPException(
                status_code=401, detail="Invalid token or already logged out"
            )

        session.delete()

        return Response(status_code=204)
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/register_user")  # type: ignore
async def register_user(
    username: str = Body(...),
    password: str = Body(...),
    email: str = Body(...),
) -> JSONResponse:
    try:
        user_obj = User.objects(username=username).first()
        if user_obj:
            raise HTTPException(status_code=405, detail="User already exists")

        hashed_password = generate_password_hash(password)
        new_user = User(
            username=username,
            password=hashed_password,
            email=email,
        )
        new_user.save()

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"description": "User registered successfully"},
        )

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

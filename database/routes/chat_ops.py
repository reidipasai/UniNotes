import datetime
import pytz

from fastapi import APIRouter, HTTPException, Body, Query
from fastapi.responses import JSONResponse

from database.models.models import ChatMessage, ChatChannel


router = APIRouter()

ath_timezone = pytz.timezone('Europe/Athens')

@router.post("/message") # type: ignore
async def message(
        user: str = Body(...),
        content: str = Body(...),
        channel: str = Body(...),
) -> JSONResponse:
    try:
        chat_channel = ChatChannel.objects(channel_name=channel).first()
        if chat_channel is None:
            raise HTTPException(
                    status_code=404,
                    detail=f"Channel: {channel} is not found"
                )
        
        now = datetime.datetime.now(ath_timezone)
        message = ChatMessage(
            user=user,
            content=content,
            channel=channel,
            sent_at=now,
        )
        message.save()

        chat_channel.messages.append(message)
        chat_channel.last_updated = now
        chat_channel.save()

        return JSONResponse(
            status_code=201,
            content={
                "message": {
                    "user": message.user,
                    "content": message.content,
                    "sent_at": now.strftime("%Y-%m-%d %H:%M:%S"),
                    "channel": message.channel
                }
            }
        )

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/messages") # type: ignore
async def fetch_messages(
    channel: str = Body(...),
    start: int = Body(0),
    end: int = Body(20),
) -> JSONResponse:
    try:
        chat_channel = ChatChannel.objects(channel_name=channel).first()
        if chat_channel is None:
            raise HTTPException(
                status_code=404,
                detail=f"Channel: {channel} is not found",
            )
        
        messages = ChatMessage.objects(channel=channel).order_by("-sent_at").skip(start).limit(end - start)
        messages_list = []
        for msg in messages:
            messages_list.append(
                {
                    "user": msg.user,
                    "content": msg.content,
                    "sent_at": msg.sent_at.strftime("%Y-%m-%d %H:%M")
                }
            )
        
        return JSONResponse(
            status_code=200,
            content={
                "messages": messages_list,
            }
        )

    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

import datetime
import pytz

from mongoengine import (
        Document,
        IntField,
        StringField,
        ListField,
        ReferenceField,
        DateTimeField,
)

ath_timezone = pytz.timezone('Europe/Athens')

class ChatMessage(Document):
    user = StringField(required=True)
    content = StringField(required=True)
    channel = StringField(required=True)
    sent_at = DateTimeField(default=lambda: datetime.datetime.now(ath_timezone))
    
    class Config:
        json_schema_extra = {
                "example": {
                    "user": "test_user",
                    "content": "Hi there",
                    "channel": "mathematics_1",
                    "sent_at": "2025-08-10 16:24:12",
                }
        }

class ChatChannel(Document):
    channel_name = StringField(required=True, unique=True)
    messages = ListField(ReferenceField(ChatMessage), default=[])
    last_updated = DateTimeField()

    class Config:
        json_schema_extra = {
                "example": {
                    "channel_name": "mathematics_1",
                    "messages": [],
                    "last_updated": "2025-08-10 16:24:12",
                }
        }


class MediaFile(Document):
    user = StringField(required=True)
    filepath = StringField(required=True)
    channel = StringField(required=True)
    file_no = IntField(required=True)
    file_type = StringField(required=True, choices=["PDF", "MP3", "M4A"])
    uploaded_at = DateTimeField(default=lambda: datetime.datetime.now(ath_timezone))
    likes = ListField(StringField(), default=[])

    class Config:
        json_schema_extra = {
            "example": {
                "user": "test_user",
                "filepath": "pdf_files/mathematics1/test_user_mathematics1_5.pdf",
                "channel": "mathematics1",
                "file_no": 5,
                "file_type": "PDF",
                "uploaded_at": "2025-08-10 16:24:12",
                "likes": ["rei", "spiros"]
            }
        }

class User(Document):
    username = StringField(required=True, unique=True)
    password = StringField(required=True)
    email = StringField(required=True, unique=True)
    favorites = ListField(StringField(), default=[])

    class Config:
        json_schema_extra = {
            "example": {
                "username": "00000",
                "password": "123456789",
                "email": "example@ntua.org",
                "favprites": ["mathematics_1", "others"]
            }
        }

class Session(Document):
    token = StringField(required=True, unique=True)
    username = StringField(required=True, unique=True)

    class Config:
        json_schema_extra = {
            "example": {"token": "123456789", "username": "00000",}
        }

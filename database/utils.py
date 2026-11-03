import os
import datetime
import mongoengine
from .models.models import User
from .models.models import ChatChannel
from werkzeug.security import generate_password_hash

TOTAL_CHANNELS = [
    'mathematics_1',
    'history',
    'physics_1',
    'linear_algebra',
    'prog_intro',
    'others',
]

def initialize_db() -> None:
    mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
    mongoengine.connect(db="uninotes", host=mongo_uri, alias="default")
    
    for channel in TOTAL_CHANNELS:
        if not ChatChannel.objects(channel_name=channel).first():
            ch = ChatChannel(
                channel_name=channel,
            )
            ch.save()

    if not User.objects(username="uninotes_admin").first():
        default_admin = User(
            username="uninotes_admin",
            password=generate_password_hash("12345"),
            email="uninotes_admin@gmail.com",
        )
        default_admin.save()

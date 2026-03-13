import os

class Config:
    APP_ENV = os.getenv("APP_ENV", "development")
    PORT = int(os.getenv("PORT", 5000))
    DEBUG = APP_ENV == "development"

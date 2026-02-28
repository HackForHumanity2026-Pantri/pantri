# Configuration settings for the Pantri application

import os

class Config:
    DEBUG = os.getenv('DEBUG', 'False') == 'True'
    DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///pantri.db')
    SECRET_KEY = os.getenv('SECRET_KEY', 'your_secret_key_here')
    ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost').split(',')
    PORT = int(os.getenv('PORT', 5000))
FROM python:3.13-alpine
WORKDIR /app
COPY poetry_service.py .
COPY media/swale-v1.wav media/swale-v1.wav
EXPOSE 8080
CMD ["python", "poetry_service.py", "serve"]

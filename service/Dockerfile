FROM python:3.13-alpine
WORKDIR /app
COPY poetry_service.py .
EXPOSE 8080
CMD ["python", "poetry_service.py", "serve"]

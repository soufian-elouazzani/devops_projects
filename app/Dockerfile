FROM python:3.12-slim

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin app \
    && mkdir -p /opt/app \
    && chown app:app /opt/app

WORKDIR /opt/app
COPY app.py /opt/app/app.py

USER app
EXPOSE 8080

ENV PORT=8080 \
    DEPLOY_COLOR=blue \
    APP_VERSION=1.0.0

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"]

CMD ["python3", "/opt/app/app.py"]

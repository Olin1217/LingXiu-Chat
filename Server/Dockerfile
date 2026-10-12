FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN groupadd --system lingxiu-api \
    && useradd --system --gid lingxiu-api --home-dir /nonexistent --shell /usr/sbin/nologin lingxiu-api

WORKDIR /app
COPY --chown=lingxiu-api:lingxiu-api lingxiu_proxy.py /app/lingxiu_proxy.py

USER lingxiu-api
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3).read()"]

CMD ["python3", "/app/lingxiu_proxy.py"]

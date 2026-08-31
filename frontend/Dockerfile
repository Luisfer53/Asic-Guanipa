FROM python:3-alpine3.23

WORKDIR /app

COPY ./build/web ./

ENV PORT=${PORT:-8000}
ENV VERSION=${VERSION:-latest}

CMD ["python", "-m", "http.server", "4000", "-b", "0.0.0.0"]

# Install dependencies only when needed
FROM node:14-slim AS deps

RUN apt update \
    && apt upgrade -y \
    && apt install -y bash git python3 python3-pip \
    && update-ca-certificates \
    && pip3 install --upgrade pip \
    && pip3 install s3cmd

WORKDIR /app

COPY entrypoint.sh ./
RUN chmod 500 ./entrypoint.sh

CMD ["/app/entrypoint.sh"]

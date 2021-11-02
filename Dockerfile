# Install dependencies only when needed
FROM node:14-slim AS deps


RUN apt update \
    && apt upgrade -y \
    && apt install -y bash git less groff curl unzip libmagic1 python3 python3-pip \
    && update-ca-certificates \
    && pip3 install --upgrade pip
    # && pip3 install --upgrade pip \
    # && pip3 install python-magic

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

WORKDIR /app

COPY entrypoint.sh ./
RUN chmod 500 ./entrypoint.sh

CMD ["/app/entrypoint.sh"]

FROM python:3.12 AS python_base

WORKDIR /app
ENV DOCKER=1

COPY ./requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app
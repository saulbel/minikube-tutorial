FROM python:3.9.12-alpine
WORKDIR /app
ADD . /app
RUN pip install -r requirements.txt
RUN chmod +x '/app/scripts/tools.sh' && /bin/sh -c '/app/scripts/tools.sh'
CMD [ "python", "app.py"]

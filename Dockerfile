FROM python:3.9.12-alpine
WORKDIR /geoblink
ADD . /geoblink
RUN pip install -r requirements.txt
RUN chmod +x '/geoblink/scripts/tools.sh' && /bin/sh -c '/geoblink/scripts/tools.sh'
CMD [ "python", "app.py"]
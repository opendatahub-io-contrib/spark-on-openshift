ARG base_img

ARG BUILD_DATE
ARG VCS_REF

FROM $base_img
LABEL maintainer="bbenzikry@gmail.com" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-url="https://github.com/bbenzikry/spark-eks.git" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.schema-version="1.0.0"\
  org.label-schema.version="0.0.1"

WORKDIR /

# Reset to root to run installation tasks
USER 0

RUN apt-get update && \
  apt install -y python python-pip && \
  apt install -y python3 python3-pip && \
  # We remove ensurepip since it adds no functionality since pip is
  # installed on the image and it just takes up 1.6MB on the image
  rm -r /usr/lib/python*/ensurepip && \
  pip install --upgrade pip setuptools && \
  pip3 install --upgrade pip setuptools && \
  # You may install with python3 packages by using pip3.6
  # Removed the .cache to save space
  rm -r /root/.cache && rm -rf /var/cache/apt/*

ENV PYTHONPATH ${SPARK_HOME}/python/lib/pyspark.zip:${SPARK_HOME}/python/lib/py4j-*.zip

WORKDIR /opt/spark/work-dir
ENTRYPOINT [ "/opt/entrypoint.sh" ]

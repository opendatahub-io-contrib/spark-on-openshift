ARG spark_uid=185
FROM openjdk:8-jdk-slim AS builder
LABEL maintainer="bbenzikry@gmail.com"

# Build options
ARG spark_version=3.0.1
ARG scala_version=2.12
ARG hive_version=2.3.7
ARG hadoop_version=3.3.0
ARG hadoop_major_version=3
ARG aws_java_sdk_version=1.11.797
ARG jmx_prometheus_javaagent_version=0.15.0

WORKDIR /

# Download JMX Prometheus javaagent jar
ADD https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${jmx_prometheus_javaagent_version}/jmx_prometheus_javaagent-${jmx_prometheus_javaagent_version}.jar /prometheus/
RUN chmod 0644 prometheus/jmx_prometheus_javaagent*.jar

WORKDIR /
# Get pre-compiled spark build
ADD https://github.com/bbenzikry/spark-glue/releases/download/${spark_version}/spark-${spark_version}-bin-hadoop-provided-glue.tgz .
RUN tar -xvzf spark-${spark_version}-bin-hadoop-provided-glue.tgz
RUN mv spark-${spark_version}-bin-hadoop-provided-glue spark


# Hadoop
ADD http://mirrors.whoishostingthis.com/apache/hadoop/common/hadoop-${hadoop_version}/hadoop-${hadoop_version}.tar.gz .
RUN tar -xvzf hadoop-${hadoop_version}.tar.gz
RUN mv hadoop-${hadoop_version} hadoop

# Delete unnecessary hadoop documentation
RUN rm -rf hadoop/share/doc

WORKDIR /spark/jars

# Add updated guava
RUN rm -f jars/guava-14.0.1.jar
ADD https://repo1.maven.org/maven2/com/google/guava/guava/23.0/guava-23.0.jar .

# Hadoop-cloud for S3A commiters
ADD https://github.com/bbenzikry/spark-glue/releases/download/${spark_version}/spark-hadoop-cloud_2.12-${spark_version}.jar .

# Add GCS and BQ just in case
ADD https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-latest-hadoop${hadoop_major_version}.jar .
ADD https://storage.googleapis.com/spark-lib/bigquery/spark-bigquery-latest_2.12.jar .
RUN chmod 0644 guava-23.0.jar spark-bigquery-latest_2.12.jar gcs-connector-latest-hadoop${hadoop_major_version}.jar spark-hadoop-cloud_2.12-${spark_version}.jar

# Updated AWS for IRSA
WORKDIR /hadoop/share/hadoop/tools/lib
RUN rm ./aws-java-sdk-bundle-*.jar
ADD https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${aws_java_sdk_version}/aws-java-sdk-bundle-${aws_java_sdk_version}.jar .
RUN chmod 0644 aws-java-sdk-bundle*.jar

FROM openjdk:8-jdk-slim as final
LABEL org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.authors='bbenzikry@gmail.com' \
  org.opencontainers.image.url='https://github.com/bbenzikry/spark-eks.git' \
  org.opencontainers.image.version=$spark_version \
  org.opencontainers.image.title="Spark ${spark_version} for EKS" \
  org.opencontainers.image.description="Spark ${spark_version} built for working with AWS services"

# Copy spark + glue + hadoop from builder stage
COPY --from=builder /spark /opt/spark
COPY --from=builder /spark/kubernetes/dockerfiles/spark/entrypoint.sh /opt

# Hadoop
COPY --from=builder /hadoop /opt/hadoop
# Copy Prometheus jars from builder stage
COPY --from=builder /prometheus /prometheus

RUN set -ex && \
  sed -i 's/http:\/\/deb.\(.*\)/https:\/\/deb.\1/g' /etc/apt/sources.list && \
  apt-get update && \
  ln -s /lib /lib64 && \
  apt install -y bash tini libc6 libpam-modules krb5-user libnss3 procps && \
  mkdir -p /opt/spark && \
  mkdir -p /opt/spark/examples && \
  mkdir -p /opt/spark/work-dir && \
  touch /opt/spark/RELEASE && \
  rm /bin/sh && \
  ln -sv /bin/bash /bin/sh && \
  echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
  chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
  rm -rf /var/cache/apt/*

ENV SPARK_HOME /opt/spark
ENV HADOOP_HOME /opt/hadoop
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:/contrib/capacity-scheduler/*.jar:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV SPARK_EXTRA_CLASSPATH="$SPARK_DIST_CLASSPATH"
ENV LD_LIBRARY_PATH /lib64

WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir
# RUN chmod a+x /opt/decom.sh 

ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}
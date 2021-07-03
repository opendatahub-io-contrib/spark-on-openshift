FROM openjdk:8-jdk-alpine AS builder

# set desired spark, hadoop and kubernetes client versions
ARG spark_version=2.4.4
ARG hadoop_version=2.8.5
ARG kubernetes_client_version=4.6.4
ARG jmx_prometheus_javaagent_version=0.15.0
ARG aws_java_sdk_version=1.11.682
ARG spark_uid=185

# Download Spark
ADD https://archive.apache.org/dist/spark/spark-${spark_version}/spark-${spark_version}-bin-without-hadoop.tgz .
# Unzip Spark
RUN tar -xvzf spark-${spark_version}-bin-without-hadoop.tgz
RUN mv spark-${spark_version}-bin-without-hadoop spark

# Download Hadoop
ADD https://archive.apache.org/dist/hadoop/common/hadoop-${hadoop_version}/hadoop-${hadoop_version}.tar.gz .
# Unzip Hadoop
RUN tar -xvzf hadoop-${hadoop_version}.tar.gz
RUN mv hadoop-${hadoop_version} hadoop
# Delete unnecessary hadoop documentation
RUN rm -rf hadoop/share/doc

# Download JMX Prometheus javaagent jar
ADD https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${jmx_prometheus_javaagent_version}/jmx_prometheus_javaagent-${jmx_prometheus_javaagent_version}.jar /prometheus/
RUN chmod 0644 prometheus/jmx_prometheus_javaagent*.jar

# Delete old spark kubernetes client jars and replace them with newer version
WORKDIR /spark
RUN rm ./jars/kubernetes-*.jar
ADD https://repo1.maven.org/maven2/io/fabric8/kubernetes-model-common/${kubernetes_client_version}/kubernetes-model-common-${kubernetes_client_version}.jar jars/
ADD https://repo1.maven.org/maven2/io/fabric8/kubernetes-client/${kubernetes_client_version}/kubernetes-client-${kubernetes_client_version}.jar jars/
ADD https://repo1.maven.org/maven2/io/fabric8/kubernetes-model/${kubernetes_client_version}/kubernetes-model-${kubernetes_client_version}.jar jars/

RUN chmod 0644 jars/kubernetes-*.jar

# Install aws-java-sdk
WORKDIR /hadoop/share/hadoop/tools/lib
ADD https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${aws_java_sdk_version}/aws-java-sdk-bundle-${aws_java_sdk_version}.jar .
RUN chmod 0644 aws-java-sdk-bundle*.jar

FROM openjdk:8-jdk-alpine as final

WORKDIR /opt/spark

# Copy Spark from builder stage
COPY --from=builder /spark /opt/spark
COPY --from=builder /spark/kubernetes/dockerfiles/spark/entrypoint.sh /opt

# Copy Hadoop from builder stage
COPY --from=builder /hadoop /opt/hadoop

# Copy Prometheus jars from builder stage
COPY --from=builder /prometheus /prometheus

RUN set -ex && \
    apk upgrade --no-cache && \
    ln -s /lib /lib64 && \
    apk add --no-cache bash tini libc6-compat linux-pam nss && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/*

# Configure environment variables for spark
ENV SPARK_HOME /opt/spark

ENV HADOOP_HOME /opt/hadoop

ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:/contrib/capacity-scheduler/*.jar:$HADOOP_HOME/share/hadoop/tools/lib/*"

ENV SPARK_EXTRA_CLASSPATH="$SPARK_DIST_CLASSPATH"

ENV LD_LIBRARY_PATH /lib64

# Set spark workdir
WORKDIR /opt/spark/work-dir
RUN chmod g+w /opt/spark/work-dir

RUN mkdir -p /etc/metrics/conf
COPY conf/metrics.properties /etc/metrics/conf
COPY conf/prometheus.yaml /etc/metrics/conf

ENTRYPOINT [ "/opt/entrypoint.sh" ]

USER ${spark_uid}

FROM registry.access.redhat.com/ubi8/openjdk-8:1.13 AS builder

# set desired spark, hadoop and kubernetes client versions
ARG spark_version=2.4.6
ARG hadoop_version=3.3.0
ARG kubernetes_client_version=4.6.4
ARG jmx_prometheus_javaagent_version=0.15.0
ARG aws_java_sdk_version=1.12.255
ARG spark_uid=185

USER 0

WORKDIR /

# Install gzip to extract archives
RUN microdnf install -y gzip && \
    microdnf clean all

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

# Delete old aws-java-sdk and replace with newer version
WORKDIR /hadoop/share/hadoop/tools/lib
RUN rm -f ./aws-java-sdk-*.jar
ADD https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${aws_java_sdk_version}/aws-java-sdk-bundle-${aws_java_sdk_version}.jar .
RUN chmod 0644 aws-java-sdk*.jar

### Build final image
FROM registry.access.redhat.com/ubi8/openjdk-8:1.13 as final

# Fix for https://issues.redhat.com/browse/OPENJDK-335
ENV NSS_WRAPPER_PASSWD=
ENV NSS_WRAPPER_GROUP=

USER 0

WORKDIR /opt/spark

# Copy Spark from builder stage
COPY --from=builder /spark /opt/spark
COPY --from=builder /spark/kubernetes/dockerfiles/spark/entrypoint.sh /opt

# Copy Hadoop from builder stage
COPY --from=builder /hadoop /opt/hadoop

# Copy Prometheus jars from builder stage
COPY --from=builder /prometheus /prometheus

# Add an init process, check the checksum to make sure it's a match
RUN set -e ; \
  TINI_BIN=""; \
  TINI_SHA256=""; \
  TINI_VERSION="v0.19.0"; \
  case "$(arch)" in \
    x86_64) \
        TINI_BIN="tini-amd64"; \
        TINI_SHA256="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c"; \
        ;; \
    aarch64) \
        TINI_BIN="tini-arm64"; \
        TINI_SHA256="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81"; \
        ;; \
    *) \
        echo >&2 ; echo >&2 "Unsupported architecture \$(arch)" ; echo >&2 ; exit 1 ; \
        ;; \
  esac ; \
  curl --retry 8 -S -L -O "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/${TINI_BIN}" ; \
  echo "${TINI_SHA256} ${TINI_BIN}" | sha256sum -c - ; \
  mv "${TINI_BIN}" /usr/bin/tini ; \
  chmod +x /usr/bin/tini

RUN set -ex && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE

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

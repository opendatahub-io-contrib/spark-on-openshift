# Note: Spark 3.3.1 supports Python up to 3.10, but we will install 3.9

ARG base_img

FROM $base_img

EXPOSE 8080

ENV PYTHON_VERSION=3.9 \
    PATH=$HOME/.local/bin/:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    CNB_STACK_ID=com.redhat.stacks.ubi8-python-39 \
    CNB_USER_ID=1001 \
    CNB_GROUP_ID=0 \
    PIP_NO_CACHE_DIR=off

USER 0

RUN INSTALL_PKGS="python39 python39-devel python39-setuptools python39-pip nss_wrapper \
        httpd httpd-devel mod_ssl mod_auth_gssapi mod_ldap \
        mod_session atlas-devel gcc-gfortran libffi-devel libtool-ltdl enchant" && \
    microdnf -y module enable python39:3.9 httpd:2.4 && \
    microdnf -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    microdnf -y clean all --enablerepo='*' && \
    ln -s /usr/bin/python3 /usr/bin/python

ENV PYTHONPATH ${SPARK_HOME}/python/lib/pyspark.zip:${SPARK_HOME}/python/lib/py4j-*.zip

WORKDIR /opt/spark/work-dir
ENTRYPOINT [ "/opt/entrypoint.sh" ]

USER 185

/opt/app-root/bin/spark-submit \
--class com.amazonaws.eks.tpcds.DataGeneration \
--master k8s://https://$KUBERNETES_SERVICE_HOST:443 \
--deploy-mode cluster \
--conf spark.kubernetes.namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace) \
--conf spark.app.name=tpcds-benchmark-data-generation-1g-v4 \
--conf spark.kubernetes.driver.pod.name=tpcds-benchmark-data-generation-1g-v4-driver \
--conf spark.kubernetes.container.image=quay.io/guimou/spark-benchmark:s3.0.1-h3.3.0_v0.0.1 \
--conf spark.kubernetes.submission.waitAppCompletion=false \
--conf spark.eventLog.enabled=true \
--conf spark.hadoop.fs.s3a.committer.name=directory \
--conf spark.hadoop.fs.s3a.input.fadvise=random \
--conf spark.network.timeout=2400 \
--conf spark.hadoop.fs.s3a.bucket.spark-history-server.secret.key=XXXXXXXXXXXXXXXXXXXX \
--conf spark.hadoop.mapreduce.outputcommitter.factory.scheme.s3a=org.apache.hadoop.fs.s3a.commit.S3ACommitterFactory \
--conf spark.metrics.conf.*.source.jvm.class=org.apache.spark.metrics.source.JvmSource \
--conf spark.metrics.namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).tpcds-benchmark-data-generation-1g-v2 \
--conf spark.metrics.conf=/etc/metrics/conf/metrics.properties \
--conf spark.hadoop.fs.s3a.bucket.spark-history-server.path.style.access=true \
--conf spark.hadoop.fs.s3a.bucket.spark-data.endpoint=s3_endpoint \
--conf spark.hadoop.fs.s3a.bucket.spark-history-server.connection.ssl.enabled=false \
--conf spark.hadoop.fs.s3a.bucket.spark-data.path.style.access=true \
--conf spark.hadoop.fs.s3a.bucket.spark-data.secret.key=XXXXXXXXXXXXXXXXXXXX \
--conf spark.hadoop.fs.s3a.fast.upload=true \
--conf spark.hadoop.fs.s3a.bucket.spark-history-server.endpoint=s3_endpoint \
--conf spark.hadoop.fs.s3a.bucket.spark-data.connection.ssl.enabled=false \
--conf spark.metrics.appStatusSource.enabled=true \
--conf spark.hadoop.fs.s3a.bucket.spark-data.access.key=XXXXXXXXXXXXXXXXXXXX \
--conf spark.speculation=false \
--conf spark.eventLog.dir=s3a://spark-history-server/logs-dir/ \
--conf spark.hadoop.fs.s3a.connection.maximum=200 \
--conf spark.hadoop.fs.s3a.connection.timeout=1200000 \
--conf spark.hadoop.fs.s3a.bucket.spark-history-server.access.key=XXXXXXXXXXXXXXXXXXXX \
--conf spark.hadoop.fs.s3a.readahead.range=256K \
--conf spark.hadoop.fs.s3a.committer.staging.conflict-mode=append \
--conf spark.driver.cores=2 \
--conf spark.kubernetes.driver.limit.cores=2048m \
--conf spark.driver.memory=8000m \
--conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-sa \
--conf spark.kubernetes.driver.annotation.prometheus.io/scrape=true \
--conf spark.kubernetes.driver.annotation.prometheus.io/port=8090 \
--conf spark.kubernetes.driver.annotation.prometheus.io/path=/metrics \
--conf spark.executor.instances=3 \
--conf spark.executor.cores=1 \
--conf spark.kubernetes.executor.limit.cores=1 \
--conf spark.executor.memory=8000m \
--conf spark.executor.memoryOverhead=2g \
--conf spark.kubernetes.executor.annotation.prometheus.io/scrape=true \
--conf spark.kubernetes.executor.annotation.prometheus.io/port=8090 \
--conf spark.kubernetes.executor.annotation.prometheus.io/path=/metrics \
local:///opt/spark/examples/jars/eks-spark-benchmark-assembly-1.0.jar \
s3a://spark-data/TPCDS-TEST-1G-V4 \
/opt/tpcds-kit/tools \
parquet \
1 \
100 \
false \
false \
true
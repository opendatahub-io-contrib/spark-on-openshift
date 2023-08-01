import sys, string
import os
import socket
from pyspark.sql import SparkSession
from datetime import datetime

if __name__ == "__main__":

    spark = SparkSession\
        .builder\
        .appName("PythonWordCount")\
        .getOrCreate()

    s3_endpoint_url = os.environ['S3_ENDPOINT_URL']
    s3_access_key_id = os.environ['AWS_ACCESS_KEY_ID']
    s3_secret_access_key = os.environ['AWS_SECRET_ACCESS_KEY']
    s3_bucket = os.environ['BUCKET_NAME']

    hadoopConf = spark.sparkContext._jsc.hadoopConfiguration()
    hadoopConf.set("fs.s3a.endpoint", s3_endpoint_url)
    hadoopConf.set("fs.s3a.access.key", s3_access_key_id)
    hadoopConf.set("fs.s3a.secret.key", s3_secret_access_key)
    hadoopConf.set("fs.s3a.path.style.access", "true")
    hadoopConf.set("fs.s3a.connection.ssl.enabled", "false")

    text_file = spark.sparkContext.textFile("s3a://" + s3_bucket + "/shakespeare.txt") \
                .flatMap(lambda line: line.split(" ")) \
                .map( lambda x: x.replace(',',' ').replace('.',' ').replace('-',' ').lower())

    sorted_counts = text_file.flatMap(lambda line: line.split(" ")) \
            .map(lambda word: (word, 1)) \
            .reduceByKey(lambda a, b: a + b) \
            .sortBy(lambda wordCounts: wordCounts[1], ascending=False)
            
    i = 0
    for word, count in sorted_counts.collect()[0:500]:
        print("{} : {} : {} ".format(i, word, count))
        i += 1
    
    now = datetime.now() # current date and time
    date_time = now.strftime("%d-%m-%Y_%H:%M:%S")

    sorted_counts.saveAsTextFile("s3a://" + s3_bucket + "/sorted_counts_" + date_time)

    spark.stop()

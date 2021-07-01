package com.sparkbyexamples.spark

import org.apache.spark.sql.SparkSession

object ParquetAWSExample extends App{

    val spark: SparkSession = SparkSession.builder()
      .appName("SparkByExamples.com")
      .getOrCreate()
    spark.sparkContext
      .hadoopConfiguration.set("fs.s3a.access.key", sys.env("AWS_ACCESS_KEY_ID"))
    spark.sparkContext
      .hadoopConfiguration.set("fs.s3a.secret.key", sys.env("AWS_SECRET_ACCESS_KEY"))
    spark.sparkContext
      .hadoopConfiguration.set("fs.s3a.endpoint", sys.env("S3_ENDPOINT_URL"))
    spark.sparkContext
      .hadoopConfiguration.set("fs.s3a.path.style.access", "true")

    val bucket = sys.env("BUCKET_NAME")

    val data = Seq(("James ","Rose","Smith","36636","M",3000),
      ("Michael","Rose","","40288","M",4000),
      ("Robert","Mary","Williams","42114","M",4000),
      ("Maria","Anne","Jones","39192","F",4000),
      ("Jen","Mary","Brown","1234","F",-1)
    )

    val columns = Seq("firstname","middlename","lastname","dob","gender","salary")
    import spark.sqlContext.implicits._
    val df = data.toDF(columns:_*)

    df.show()
    df.printSchema()

    df.write
      .parquet("s3a://" + bucket + "/parquet/people.parquet")


    val parqDF = spark.read.parquet("s3a://" + bucket + "/parquet/people.parquet")
    parqDF.createOrReplaceTempView("ParquetTable")

    spark.sql("select * from ParquetTable where salary >= 4000").explain()
    val parkSQL = spark.sql("select * from ParquetTable where salary >= 4000 ")

    parkSQL.show()
    parkSQL.printSchema()

    df.write
      .partitionBy("gender","salary")
      .parquet("s3a://" + bucket + "/parquet/people2.parquet")

//    val parqDF2 = spark.read.parquet("s3a://" + bucket + "/parquet/people2.parquet")
//    parqDF2.createOrReplaceTempView("ParquetTable2")
//
//    val df3 = spark.sql("select * from ParquetTable2  where gender='M' and salary >= 4000")
//    df3.explain()
//    df3.printSchema()
//    df3.show()
//
//    val parqDF3 = spark.read
//      .parquet("s3a://" + bucket + "/parquet/people.parquet/gender=M")
//    parqDF3.show()


}

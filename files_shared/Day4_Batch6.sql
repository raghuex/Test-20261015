create database perf_db6;

create stage files_stg directory = (enable = true) encryption = (type = 'SNOWFLAKE_SSE');

list @files_stg;

select $1 from @files_stg;

create table transactions (Transaction_Date date,Transaction_ID int, Customer_ID int, Amount int);

copy into transactions
from @files_stg
file_format = (skip_header = 1 field_delimiter = '|')
;

create table transactions_large (Transaction_Date date,Transaction_ID int, Customer_ID int, Amount int);

desc table transactions;

insert into transactions_large
select
a.TRANSACTION_DATE + mod(random(), 2000) as TRANSACTION_DATE
,random() as TRANSACTION_ID
,a.CUSTOMER_ID
,a.AMOUNT
from transactions a cross join transactions b cross join transactions c cross join transactions d
;

select count (distinct CUSTOMER_ID) from transactions; -- 100
select count (distinct TRANSACTION_ID) from transactions; -- 100
select count (distinct CUSTOMER_ID) from transactions_large; -- 100
select count (distinct TRANSACTION_ID) from transactions_large; -- 100M
select count (distinct TRANSACTION_DATE = '';) from transactions_large; -- 4718
select TRANSACTION_DATE, count(*) from transactions_large group by 1 order by 1 desc;

select * from transactions_large; -- 100000000,37/37 ~2702702

show parameters;
alter session set USE_CACHED_RESULT = false;
alter warehouse first_wh suspend;

select * from transactions_large where TRANSACTION_DATE = '2026-03-04'; -- 236, 1.0s, 14/37
select * from transactions_large where TRANSACTION_DATE = '2020-11-23'; -- 24882, 1.7s, 37/37
select * from transactions_large where TRANSACTION_DATE = '2013-04-04'; -- 237, 802ms, 7/37


show tables;
alter table transactions_large cluster by (TRANSACTION_DATE);


SELECT SYSTEM$CLUSTERING_INFORMATION('transactions_large', '(TRANSACTION_DATE)');
/*
{
  "cluster_by_keys" : "LINEAR(TRANSACTION_DATE)",
  "notes" : "Clustering key columns contain high cardinality key TRANSACTION_DATE which might result in expensive re-clustering. Consider reducing the cardinality of clustering keys. Please refer to https://docs.snowflake.net/manuals/user-guide/tables-clustering-keys.html for more information.",
  "total_partition_count" : 37,
  "total_constant_partition_count" : 0,
  "average_overlaps" : 36.0,
  "average_depth" : 37.0,
  "version" : "OPTIMA",
  "clustering_errors" : [ ]
}
*/


select *
  from table(information_schema.automatic_clustering_history(
    date_range_start=>dateadd(H, -12, current_timestamp)));
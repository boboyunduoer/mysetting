----------------------------------------------------------------------LIST:
1. list all schema
db2 -x list tables for all | grep -v SYS | awk '{print $2}' | uniq

2. list all tables
db2 -x list tables for all | grep -v SYS | grep ' T ' | awk '{print $2"."$1}'

3. list all tables for schemaName
db2 -x list tables for schema schemaName | grep ' T ' | awk '{print $2"."$1}'

4. list all local databases
db2 list db directory | awk ' /Indirect/' RS=""

5. list all application id
db2 list applications | sed '1,4'd | sed '$'d| awk '{print $3 ","}'
db2 list applications for db dbName | sed '1,4'd | sed '$'d| awk '{print $3 ","}'

-----------------------------------------------------------------DB
-- db size
db2 "call get_dbsize_info(?,?,?,-1)"

-----------------------------------------------------------------table
--table size
select  substr(t.tabschema,1,18) as tabschema , substr(t.tabname,1,40) as tabname , tableorg
        , (COL_OBJECT_P_SIZE + DATA_OBJECT_P_SIZE + INDEX_OBJECT_P_SIZE + LONG_OBJECT_P_SIZE + LOB_OBJECT_P_SIZE + XML_OBJECT_P_SIZE)/1024 as tab_size_mb
from    syscat.tables t
join sysibmadm.admintabinfo ati on t.tabname=ati.tabname and t.tabschema=ati.tabschema
where   t.type='T' and t.tabschema not like ('SYS%')
order by tab_size_mb desc fetch first 10 rows only with ur

-----------------------------------------------------------------schema
db2 "call ADMIN_DROP_SCHEMA('SCHEMA_TO_DROP', NULL, 'ERROR_TABLE_SCHEMA_NAME', 'ERROR_TABLE_TABLE_NAME')"

-----------------------------------------------------------------bufferpool
db2 "WITH BPMETRICS AS (
    SELECT bp_name,
           pool_data_l_reads + pool_temp_data_l_reads +
           pool_index_l_reads + pool_temp_index_l_reads +
           pool_xda_l_reads + pool_temp_xda_l_reads as logical_reads,
           pool_data_p_reads + pool_temp_data_p_reads +
           pool_index_p_reads + pool_temp_index_p_reads +
           pool_xda_p_reads + pool_temp_xda_p_reads as physical_reads,
           member
    FROM TABLE(MON_GET_BUFFERPOOL('',-2)) AS METRICS)
   SELECT
    VARCHAR(bp_name,20) AS bp_name,
    logical_reads,
    physical_reads,
    CASE WHEN logical_reads > 0
     THEN DEC((1 - (FLOAT(physical_reads) / FLOAT(logical_reads))) * 100,5,2)
     ELSE NULL
    END AS HIT_RATIO,
    member
   FROM BPMETRICS"

-----------------------------------------------------------------TableSpaces, CONTAINER
SELECT * FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t ;

select * FROM TABLE(MON_GET_CONTAINER('',-2)) AS t;
--
b2pd -db dbname -tablespaces

select * from syscat.tablespaces where DATATYPE = 'T'

--backup pending
select varchar(tbsp_name, 30) as tbsp_name, varchar(tbsp_state, 40) as tbsp_state 
from table(mon_get_tablespace('',null)) as t where tbsp_state = 'BACKUP_PENDING'
--backup database adw tablespace (xyz) online to /dev/null

--get sql which used temp tablespace most
db2 "WITH SUM_TAB (SUM_RR, SUM_CPU, SUM_EXEC, SUM_SORT, SUM_NUM_EXEC, SUM_TMP_READS) AS (
        SELECT  FLOAT(SUM(ROWS_READ))+1,
                FLOAT(SUM(TOTAL_CPU_TIME))+1,
                FLOAT(SUM(STMT_EXEC_TIME))+1,
                FLOAT(SUM(TOTAL_SECTION_SORT_TIME))+1,
                FLOAT(SUM(NUM_EXECUTIONS))+1,
                FLoat(SUM(POOL_TEMP_DATA_L_READS+POOL_TEMP_XDA_L_READS+POOL_TEMP_INDEX_L_READS)) +1
            FROM TABLE(MON_GET_PKG_CACHE_STMT ( 'D', NULL, NULL, -2)) AS T
        )
SELECT
        varchar(LEFT(INSERT_TIMESTAMP,19),20) INSERT_TIMESTAMP,
        int(POOL_TEMP_DATA_L_READS+POOL_TEMP_XDA_L_READS+POOL_TEMP_INDEX_L_READS) TMP_READS,
        DECIMAL(100*(FLOAT(POOL_TEMP_DATA_L_READS+POOL_TEMP_XDA_L_READS+POOL_TEMP_INDEX_L_READS)/SUM_TAB.SUM_TMP_READS),5,2) AS PCT_TOT_TMP,
        int(STMT_EXEC_TIME) STMT_EXEC_TIME,
        DECIMAL(100*(FLOAT(STMT_EXEC_TIME)/SUM_TAB.SUM_EXEC),5,2) AS PCT_TOT_EXEC,
        int(NUM_EXECUTIONS) NUM_EXECUTIONS,
        DECIMAL(100*(FLOAT(NUM_EXECUTIONS)/SUM_TAB.SUM_NUM_EXEC),5,2) AS PCT_TOTN_EXEC,
        DECIMAL(FLOAT(STMT_EXEC_TIME)/FLOAT(NUM_EXECUTIONS+1),10,2) AS AVG_EXEC_TIME,
        substr(STMT_TEXT,1,50) STMT_TEXT
    FROM TABLE(MON_GET_PKG_CACHE_STMT ( 'D', NULL, NULL, -2)) AS T, SUM_TAB
    ORDER BY TMP_READS DESC FETCH FIRST 20 ROWS ONLY WITH UR"

-----------------------------------------------------------------LOCK:
select * from SYSIBMADM.MON_LOCKWAITS where tabschema =  'ADWHPSD8' and tabname = 'D_TKSTATUSHIST' ;

--below is deprecated   
db2 "select SUBSTR(DB_NAME,1,8) DB_NAME, SUBSTR(AGENT_ID,1,10) AGENT_ID, SUBSTR(APPL_NAME,1,20) APPL_NAME, SUBSTR(AUTHID,1,10) AUTHID, SUBSTR(TBSP_NAME,1,20) TBSP_NAME,SUBSTR(TABSCHEMA,1,10) TABSCHEMA, SUBSTR(TABNAME,1,20) TABNAME, LOCK_OBJECT_TYPE,LOCK_MODE,LOCK_STATUS from SYSIBMADM.LOCKS_HELD where tabschema =  'ADWREMB6' and tabname = 'F_PBMMETRIC'"

-----------------------------------------------------------------LOG:
-- 1. Log overview in SYSIBMADM.MON_TRANSACTION_LOG_UTILIZATION
db2 "select * from SYSIBMADM.MON_TRANSACTION_LOG_UTILIZATION"

-- 2. Log overview in SYSPROC.MON_GET_TRANSACTION_LOG
db2 "select TOTAL_LOG_AVAILABLE,TOTAL_LOG_USED,FIRST_ACTIVE_LOG, LAST_ACTIVE_LOG, CURRENT_ACTIVE_LOG, APPLID_HOLDING_OLDEST_XACT from table(SYSPROC.mon_get_transaction_log(-1)) as t"
--db2 get snapshot for database on adw | grep -i 'Appl id holding the oldest transaction'
--    column APPLID_HOLDING_OLDEST_XACT is equal to below info: (notes that holding means no commit)
--    PS C:\> db2 get snapshot for db on sample  | grep -i oldest
--    Appl id holding the oldest transaction     = 8007
    
-- 3. log used for each application
db2 "select application_handle,UOW_LOG_SPACE_USED,workload_OCCURRENCE_STATE FROM TABLE(MON_GET_UNIT_OF_WORK(NULL,-1)) order by UOW_LOG_SPACE_USED"
--db2 get snapshot for applications on adw |grep -i -e "Application handle" -e "UOW log space used"


----------------------------------------------------------------- loop delete
for (( c=1; c<=100; c++ )); do db2 "delete from(select * from TVCDBADM.TVC where report_date >= '2017-07-01' and report_date <= '2017-07-31' fetch first 2000 rows only)" ; done

----------------------------------------------------------------- restart id
SELECT MAX(mycolumn)+ 1 FROM mytable;
ALTER TABLE mytable ALTER COLUMN mycolumn RESTART WITH <above_result>;

----------------------------------------------------------------- backup 
--'B'表示备份,'N'表示数据库在线备份
select * from sysibmadm.db_history where start_time > current timestamp -3 days and operation='B' and operationtype='N'  

----------------------------------------------------------------- identity value
select tabschema,tabname,colname, lastassignedval, nextcachefirstvalue from SYSIBM.SYSSEQUENCES s join SYSCAT.COLIDENTATTRIBUTES tr on tr.seqid = s.seqid where tabschema = 'ADWMSTR' and tabname = 'D_COMPANY' and colname='ID'

----------------------------------------------------------------- FK foreign key
--good artical for fk
--https://www.databasejournal.com/features/db2/article.php/3870031/Referential-Integrity-Best-Practices-for-IBM-DB2.htm
select * from syscat.references where reftabschema = 'ADWACD' and reftabname='D_ACDRECORD';
--drop all fk
SELECT 'ALTER TABLE ' || RTRIM(TabName) || ' DROP FOREIGN KEY ' || RTRIM(ConstName) || ';' FROM SysCat.TabConst WHERE Type='F';
--disable/enable fk
SELECT 'ALTER TABLE ' || RTRIM(TabName) || ' ALTER FOREIGN KEY ' || RTRIM(ConstName) || ' NOT ENFORCED;' FROM SysCat.TabConst WHERE Type='F'; -- when not enforced, fk is just a  informational constraints in table
SELECT 'ALTER TABLE ' || RTRIM(TabName) || ' ALTER FOREIGN KEY ' || RTRIM(ConstName) || ' ENFORCED;' FROM SysCat.TabConst WHERE Type='F';     -- when enforced, it is like newly create fk, so if data does not actually conform to the constraint, enforce will fail
-- fk list info
select substr(R.reftabschema,1,10) as P_Schema, substr(R.reftabname,1,50) as PARENT, substr(R.tabschema,1,10) as C_Schema, substr (R.tabname,1,50) as CHILD,substr(R.constname,1,100) as CONSTNAME,substr(LISTAGG(C.colname,',') WITHIN GROUP (ORDER BY C.colseq),1,100) as FKCOLS
from syscat.references R, syscat.keycoluse C where R.constname = C.constname and R.tabschema = C.tabschema and R.tabname = C.tabname group by R.reftabschema, R.reftabname, R.tabschema, R.tabname, R.constname
--circular fk dependencies 
select substr(a.tabname,1,20)tabname,substr(a.reftabname,1,20)reftabname, substr(a.constname,1,20)constname from syscat.references a where exists (select 1 from syscat.references b where a.reftabname=b.tabname and a.tabname = b.reftabname)

-----------------------------------------------------------------import export load
--export to csv
TAB_NAME=cps.acrep_people
DEL_CHAR=","
db2 "export to ${TAB_NAME}_tmp.csv of del MODIFIED BY COLDEL${DEL_CHAR} select * from $TAB_NAME"
db2 -x describe table $TAB_NAME | awk '{print $1}' | $(echo "paste -s -d${DEL_CHAR}" - ${TAB_NAME}_tmp.csv) > $TAB_NAME.csv
rm -rf ${TAB_NAME}_tmp.csv

--load redefine
while IFS=! read xxx table ixf xxxxx
do
echo "load from $ixf of IXF modified by identityoverride replace into $table" ";"
done < db2move.lst

-----------------------------------------------------------------shell db2
-- Backtick command substitution is permitted
HowMany=`db2 -x "SELECT COUNT(1) FROM SYSCAT.COLUMNS WHERE TABNAME = 'TableA' AND TABSCHEMA='SchemaA' AND GENERATED = 'A'"`
-- This command substitution syntax will also work
HowMany=$(db2 -x "SELECT COUNT(1) FROM SYSCAT.COLUMNS WHERE TABNAME = 'TableA' AND TABSCHEMA='SchemaA' AND GENERATED = 'A'")
-- One way to get rid of leading spaces
Counter=`echo $HowMany`

# A while loop that is fed by process substitution cannot use 
# the current DB2 connection context, but combining a here 
# document with command substitution will work
while read HowMany ;
do
  Counter=$HowMany
  echo $HowMany
done <<EOT
$(db2 -x "SELECT COUNT(1) FROM SYSCAT.COLUMNS WHERE TABNAME = 'TableA' AND TABSCHEMA='SchemaA' AND GENERATED = 'A'")
EOT

#below used to print but could not be used as var assign value, because var1, var2 is just local var
db2 -x "select 1 id1, 11 id2 from sysibm.dual" | while read var1 var2 ; do
    echo $var1 $var2
done

-----------------------------------------------------------------top 10 sql
https://www.ibm.com/developerworks/data/library/techarticle/dm-1211packagecache/index.html
https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=2&cad=rja&uact=8&ved=2ahUKEwjqjb-7mNLgAhWWWysKHRVhA00QFjABegQICRAB&url=https%3A%2F%2Fwww.ibm.com%2Fdeveloperworks%2Fdata%2Flibrary%2Ftecharticle%2Fdm-1407monitoring%2Findex.html&usg=AOvVaw3aryIvrdBo1AU_ywzxZAiJ
https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.sql.rtn.doc/doc/r0023171.html
SELECT AVERAGE_EXECUTION_TIME_S as TIME_SECONDS, NUM_EXECUTIONS as EXECUTIONS, STMT_TEXT as TEXT FROM SYSIBMADM.TOP_DYNAMIC_SQL WHERE upper(STMT_TEXT) like 'SELECT%' ORDER BY AVERAGE_EXECUTION_TIME_S DESC FETCH FIRST 10 ROWS ONLY

SYSIBMADM.SNAPDYN_SQL administrative view and SYSPROC.SNAP_GET_DYN_SQL table function

-----------------------------------------------------------------monitor report
--The MONREPORT module provides a set of procedures for retrieving a variety of monitoring data and generating text reports.
--The schema for this module is SYSIBMADM.
call monreport.dbsummary

-----------------------------------------------------------------table function column overview
db2 "describe select * from TABLE(MON_GET_PKG_CACHE_STMT ( 'D', NULL, NULL, -2))" | less -S

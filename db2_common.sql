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

6.
db2 list db directory | grep SAMPLE -A7 -B2

-----------------------------------------------------------------Infinite width
db2 "select * from syscat.tables" | less -S
db2 "select * from syscat.tables" | vim -
db2 "select * from syscat.tables" | pspg -s 6

git clone https://github.com/okbob/pspg.git
cd pspg
./configure
make
make install

pspg -s where -s stands for color scheme (1-14)

-----------------------------------------------------------------dblook
db2look -d dbname -e -nofed -z MYSCHEMA -tw DP\_PB%

cd /home/db2inst1/sqllib/bnd
db2 "bind db2look.bnd blocking all GRANT_GROUP db2dba sqlerror continue"
db2 "bind db2lkfun.bnd blocking all GRANT_GROUP db2dba sqlerror continue"
db2 "bind db2lksp.bnd  blocking all GRANT_GROUP db2dba sqlerror continue"

-----------------------------------------------------------------DB creation
CREATE DATABASE TESTDB ON /db_data/ DBPATH ON /db_path
update db cfg using NEWLOGPATH /db_actlogs/db_name/db2_instance_name;
update db cfg using LOGARCHMETH1 DISK:/db_arclogs;

update dbm cfg using DIAGPATH /db/db2inst1/db2diag

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
order by tab_size_mb desc fetch first 20 rows only with ur

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
-- tablespace oview
db2 "select char(TBSP_NAME,20) TABLESPACE, TBSP_PAGE_SIZE, TBSP_TOTAL_PAGES,TBSP_USED_PAGES,TBSP_PAGE_TOP,((TBSP_TOTAL_PAGES-TBSP_PAGE_TOP-1)*TBSP_PAGE_SIZE)/1024/1024 RECLAIM_MB from table (MON_GET_TABLESPACE(NULL,-1)) where TBSP_NAME not like 'SYS%' and tbsp_type != 'SMS'"

-- 回收空间 节省磁盘空间
select 'db2 " ALTER TABLESPACE ' || char(TBSP_NAME,20)  || ' REDUCE ' || varchar(((TBSP_TOTAL_PAGES-TBSP_PAGE_TOP-1)*TBSP_PAGE_SIZE)/1024/1024) || ' M"' from table (MON_GET_TABLESPACE(NULL,-1)) where  TBSP_NAME not like 'SYS%' and tbsp_type != 'SMS'

select * FROM TABLE(MON_GET_CONTAINER('',-2)) AS t;
--
b2pd -db dbname -tablespaces

select distinct DATATYPE from syscat.tablespaces where DATATYPE = 'T'

-- all tablespace state
select distinct tbsp_state from table(mon_get_tablespace('',null)) as t 

--backup pending
select varchar(tbsp_name, 30) as tbsp_name, varchar(tbsp_state, 40) as tbsp_state 
from table(mon_get_tablespace('',null)) as t where tbsp_state = 'BACKUP_PENDING'
--backup database dbName tablespace (xyz) online to /dev/null

--get sql which used temp tablespace most
--https://datageek.blog/2017/08/29/db2-temporary-table-spaces/
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
select * from SYSIBMADM.MON_LOCKWAITS where tabschema =  'MYSCHEMA' and tabname = 'MYTABLE' ;

--below is deprecated   
db2 "select SUBSTR(DB_NAME,1,8) DB_NAME, SUBSTR(AGENT_ID,1,10) AGENT_ID, SUBSTR(APPL_NAME,1,20) APPL_NAME, SUBSTR(AUTHID,1,10) AUTHID, SUBSTR(TBSP_NAME,1,20) TBSP_NAME,SUBSTR(TABSCHEMA,1,10) TABSCHEMA, SUBSTR(TABNAME,1,20) TABNAME, LOCK_OBJECT_TYPE,LOCK_MODE,LOCK_STATUS from SYSIBMADM.LOCKS_HELD where tabschema =  'MYSCHEMA' and tabname = 'MYTABLE'"

-----------------------------------------------------------------LOG:
-- 1. Log overview in SYSIBMADM.MON_TRANSACTION_LOG_UTILIZATION
db2 "select * from SYSIBMADM.MON_TRANSACTION_LOG_UTILIZATION"

-- 2. Log overview in SYSPROC.MON_GET_TRANSACTION_LOG
db2 "select TOTAL_LOG_AVAILABLE,TOTAL_LOG_USED,FIRST_ACTIVE_LOG, LAST_ACTIVE_LOG, CURRENT_ACTIVE_LOG,METHOD1_NEXT_LOG_TO_ARCHIVE, APPLID_HOLDING_OLDEST_XACT from table(SYSPROC.mon_get_transaction_log(-1)) as t"
--db2 get snapshot for database on dbName | grep -i 'Appl id holding the oldest transaction'
--    column APPLID_HOLDING_OLDEST_XACT is equal to below info: (notes that holding means no commit)
--    PS C:\> db2 get snapshot for db on sample  | grep -i oldest
--    Appl id holding the oldest transaction     = 8007

-----------------------------------------------------------------backup and restore:
db2 backup db $DB_NAME online include logs										
db2 restore db $DB_NAME from /home/db2inst1 taken at $TIMESTAMP logtarget /home/db2inst1/logs/ redirect										
db2 restore db $DB_NAME continue		

--only get log
restore db dbName logs from . logtarget /home/db2inst1/logs							
										
db2 rollforward database $DB_NAME query status										
db2 "rollforward db $DB_NAME to end of logs and complete overflow log path (/home/db2inst1/logs)"
db2 "rollforward db $DB_NAME to end of backup and complete"
--generate scripts									
db2 "restore db parphdb  FROM /ers/backup/parphdb into parphdb redirect generate script /ers/backup/parphdb/new_db.sql"

-- 3. log used for each application
db2 "select application_handle,UOW_LOG_SPACE_USED,workload_OCCURRENCE_STATE FROM TABLE(MON_GET_UNIT_OF_WORK(NULL,-1)) order by UOW_LOG_SPACE_USED"
--db2 get snapshot for applications on dbName |grep -i -e "Application handle" -e "UOW log space used"

----------------------------------------------------------------- explain
--Create the explain tables in the SYSTOOLSPACE tablespace, using the SYSTOOLS schema
call sysproc.sysinstallobjects('EXPLAIN','C',NULL,NULL)
call sysproc.sysinstallobjects('EXPLAIN','D',NULL,NULL)
-- Create the explain tables in the specific schema
call sysproc.sysinstallobjects('EXPLAIN','C',NULL,'YOUR_SCHEMA_NAME')
call sysproc.sysinstallobjects('EXPLAIN','D',NULL,'YOUR_SCHEMA_NAME')
-- Create the explain tables in the specific schema and tablespace
call sysproc.sysinstallobjects('EXPLAIN','C','YOUR_TABLESPACE_NAME','YOUR_SCHEMA_NAME')

----------------------------------------------------------------- loop delete
for (( c=1; c<=100; c++ )); do db2 "delete from(select * from TVCDBADM.TVC where report_date >= '2017-07-01' and report_date <= '2017-07-31' fetch first 2000 rows only)" ; done

----------------------------------------------------------------- restart id
SELECT MAX(mycolumn)+ 1 FROM mytable;
ALTER TABLE mytable ALTER COLUMN mycolumn RESTART WITH <above_result>;

----------------------------------------------------------------- backup 
--'B'表示备份,'N'表示数据库在线备份
select * from sysibmadm.db_history where start_time > current timestamp -3 days and operation='B' and operationtype='N'  

----------------------------------------------------------------- identity value
select tabschema,tabname,colname, lastassignedval, nextcachefirstvalue from SYSIBM.SYSSEQUENCES s join SYSCAT.COLIDENTATTRIBUTES tr on tr.seqid = s.seqid where tabschema = 'MYSCHEMA' and tabname = 'MYTABLE' and colname='ID'

----------------------------------------------------------------- FK foreign key
--note that when table dropped, the fk references on this table are all dropped.
--good artical for fk
--https://www.databasejournal.com/features/db2/article.php/3870031/Referential-Integrity-Best-Practices-for-IBM-DB2.htm
db2 "select varchar(tabschema,10) tabschema,varchar(tabname,20) tabname,varchar(reftabschema,10) reftabschema,varchar(reftabname,20) reftabname, varchar(constname,30) constname, varchar(refkeyname,30) refkeyname, colcount from syscat.references 
     where reftabschema = 'ADWSRNCT' and reftabname='F_METRICSUM'"
----GSMART used:


select 'ALTER TABLE ' || TRIM(rf.tabschema) || '.' ||  RTRIM(rf.TabName) || ' ALTER FOREIGN KEY ' || RTRIM(rf.ConstName) || ' NOT  ENFORCED;' from syscat.references rf join syscat.tables tb on rf.reftabschema = tb.tabschema and rf.reftabname = tb.tabname where tb.tabschema = 'MYSCHEMA'  and tb.type = 'T' and tb.tabname like 'D/_%' escape '/'

select 'ALTER TABLE ' || TRIM(rf.tabschema) || '.' ||  RTRIM(rf.TabName) || ' ALTER FOREIGN KEY ' || RTRIM(rf.ConstName) || '  ENFORCED;' from syscat.references rf join syscat.tables tb on rf.reftabschema = tb.tabschema and rf.reftabname = tb.tabname where tb.tabschema = 'MYSCHEMA'  and tb.type = 'T' and tb.tabname like 'D/_%' escape '/'


---select tabname from syscat.tables where tabschema = 'MYSCHEMA'  and type = 'T' and tabname like 'D/_%' escape '/'
----- disable/enable all fk which is ref on xxx table
----- when not enforced, fk is just a  informational constraints in table
----- when enforced, it is like newly create fk, so if data does not actually conform to the constraint, enforce will fail
---select 'ALTER TABLE ' || TRIM(tabschema) || '.' ||  RTRIM(TabName) || ' ALTER FOREIGN KEY ' || RTRIM(ConstName) || ' NOT  ENFORCED;' from syscat.references where reftabschema = 'MYSCHEMA' and reftabname='MYTABLE';
---select 'ALTER TABLE ' || TRIM(tabschema) || '.' ||  RTRIM(TabName) || ' ALTER FOREIGN KEY ' || RTRIM(ConstName) || '   ENFORCED;' from syscat.references where reftabschema = 'MYSCHEMA' and reftabname='MYTABLE';
----GSMART used

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

--FK test sample
drop table FK_TEST.TEST1;
drop table FK_TEST.TEST2;

CREATE TABLE FK_TEST.TEST1  (id1 INTEGER NOT NULL ,id2 INTEGER );
ALTER TABLE FK_TEST.TEST1 ADD CONSTRAINT TEST1_PK PRIMARY KEY (id1);
                
CREATE TABLE FK_TEST.TEST2  (id1 INTEGER ,id2 INTEGER);
ALTER TABLE FK_TEST.TEST2 ADD CONSTRAINT TEST2_FK FOREIGN KEY (id1) REFERENCES FK_TEST.TEST1 (id1) ON DELETE RESTRICT ON UPDATE no action;
        
insert into FK_TEST.TEST1 values (1,1),(2,2),(3,3);
insert into FK_TEST.TEST2 values (2,2);

select * from FK_TEST.TEST1;
select * from FK_TEST.TEST2;

update FK_TEST.TEST1 set id1= id1+1;

--restict or no action 
-- for update differ see above sample
-- for delete differ
An after trigger is fired after the DELETE is performed, and after a constraint rule of RESTRICT (where checking is performed immediately), but before a constraint rule of NO ACTION (where checking is performed at the end of the statement)

-----------------------------------------------------------------import export load
--export to csv
TAB_NAME=cps.acrep_people
DEL_CHAR=","
db2 "export to ${TAB_NAME}_tmp.csv of del MODIFIED BY COLDEL${DEL_CHAR} select * from $TAB_NAME"
{ db2 -x describe table $TAB_NAME | awk '{print $1}' | paste -s -d${DEL_CHAR} | sed 's/[^,]*/"&"/g' && cat ${TAB_NAME}_tmp.csv ; } > $TAB_NAME.csv
rm -rf ${TAB_NAME}_tmp.csv
echo $TAB_NAME.csv && cat $TAB_NAME.csv


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
while read HowMany1 HowMany2 ;
do
  echo $HowMany1 
  echo $HowMany2
done <<EOT
$(db2 -x  "values (1,2)")
EOT

while read HowMany1 HowMany2 ;
do
  echo $HowMany1 
  echo $HowMany2
done <<-EOT
$(db2 -x  "values (1,2)")
    EOT #here must be tab , blank will not work

#below used to print but could not be used as var assign value, because var1, var2 is just local var
db2 -x "select 1 id1, 11 id2 from sysibm.dual" | while read var1 var2 ; do
    echo $var1 $var2
done

#
set -- $(db2 -x "values (1,1),(2,2)")
echo $1 $2 $3 $4
until [ -z "$1" ]
do
value1=$1
shift
value2=$1
shift
echo "$value1 $value2"
done
-----------------------------------------------------------------top 10 sql
https://www.ibm.com/developerworks/data/library/techarticle/dm-1211packagecache/index.html
https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=2&cad=rja&uact=8&ved=2ahUKEwjqjb-7mNLgAhWWWysKHRVhA00QFjABegQICRAB&url=https%3A%2F%2Fwww.ibm.com%2Fdeveloperworks%2Fdata%2Flibrary%2Ftecharticle%2Fdm-1407monitoring%2Findex.html&usg=AOvVaw3aryIvrdBo1AU_ywzxZAiJ
https://www.ibm.com/support/knowledgecenter/en/SSEPGG_11.1.0/com.ibm.db2.luw.sql.rtn.doc/doc/r0023171.html
SELECT AVERAGE_EXECUTION_TIME_S as TIME_SECONDS, NUM_EXECUTIONS as EXECUTIONS, STMT_TEXT as TEXT FROM SYSIBMADM.TOP_DYNAMIC_SQL WHERE upper(STMT_TEXT) like 'SELECT%' ORDER BY AVERAGE_EXECUTION_TIME_S DESC FETCH FIRST 10 ROWS ONLY

SYSIBMADM.SNAPDYN_SQL administrative view and SYSPROC.SNAP_GET_DYN_SQL table function

-----------------------------------------------------------------monitor report
--The MONREPORT module provides a set of proc for retrieving a variety of monitoring data and generating text reports.
--The schema for this module is SYSIBMADM.
call monreport.dbsummary

-----------------------------------------------------------------table function column overview
db2 "describe select * from TABLE(MON_GET_PKG_CACHE_STMT ( 'D', NULL, NULL, -2))" | less -S

-----------------------------------------------------------------db2diag
db2diag -time 2017-01-24-19.00:2017-01-24-23.59.59
db2diag -gi level=severe

-----------------------------------------------------------------db2 uninstall
1.drop all databases    --drop database <NAME>															
2.stop all db2 instances  --./db2idrop <INSTANCE NAME>	    cd /opt/IBM/db2/V9.7/instance									
3.uninstall db2  --./db2_deinstall -a						cd /opt/IBM/db2/V9.7/install		

-----------------------------------------------------------------db2 restore
db2 "restore db parphdb  FROM /ers/backup/parphdb into parphdb redirect generate script /ers/backup/parphdb/new_db.sql"

-----------------------------------------------------------------db2 alter
db2 "alter table tabname ALTER colname drop not null"   --修改列的属性为null
db2 "alter table t01 ALTER colname set not null"        --#回退步骤
--因为修改列的属性后，该表处于reorg pending状态所以我们必须进行reorg才能使该表恢复到正常状态（这一步很重要）
db2 "reorg table tabname use tempsys"
db2 "runstats on table tabname with distribution and detailed indexes all"

--===验证 table status
db2 load query table tabname

-----------------------------------------------------------------escape char
select  case when '1''' = '1\"' then 1 else 0 end c1 from sysibm.dual;
select * from  sysibm.dual where '%' like '%!%%' escape '!'

-----------------------------------------------------------------PROCEDURES
select procschema,procname from SYSCAT.PROCEDURES where procschema = 'MYSCHEMA';

----------------------------------------------------------------- Privileges, authorities
https://datageek.blog/2018/01/23/db2-basics-investigating-permissions-in-an-existing-database/
--If you want a list of all IDs that have system or database authorities, using SYSIBMADM.AUTHORIZATIONIDS.
db2 "select substr(authid,1,20) as authid, authidtype from sysibmadm.authorizationids"

--Check implicit/explicit Authorities for AUTHID at both the system/instance and database level, using the AUTH_LIST_AUTHORITIES_FOR_AUTHID table function
--It also tells you how that entity(user/group/role) got that authority – through a direct grant, a group, a role, or PUBLIC
--* means no one can gain that permission via the method specified in the column name.
db2 "SELECT varchar(AUTHORITY,40) Authority, D_USER, D_GROUP, D_PUBLIC, ROLE_USER, ROLE_GROUP, ROLE_PUBLIC, D_ROLE FROM TABLE(SYSPROC.AUTH_LIST_AUTHORITIES_FOR_AUTHID (UPPER('PUBLIC'), 'G') ) AS T ORDER BY Authority"

--Check EXPLICIT privileges for AUTHID on an individual object level, using SYSIBMADM.PRIVILEGES view
db2 "SELECT varchar(AUTHID,10) ID, varchar(OBJECTSCHEMA,20) SCHEMA, varchar(OBJECTNAME,30) OBJECT, OBJECTTYPE, privilege FROM SYSIBMADM.PRIVILEGES where AUTHID = UPPER('PUBLIC') order by object, privilege with ur"

-------------------old way
1. check DBM CFG for system level, e.g SYSADM_GROUP
   db2 get dbm cfg |grep GROUP
2. query SYSCAT.DBAUTH to get all database level authorizations
3. Finally query each of the other authorization system views – SYSCAT.TABAUTH, SYSCAT.INDEXAUTH, etc

-----------------------------------------------------------------db2jcc
java com.ibm.db2.jcc.DB2Jcc -url "jdbc:db2://IP:50001/DBNAME:sslConnection=true;sslCertLocation=/certificate/full/path/certificate.arm;" -user xxxx -password xxxx

echo $CLASSPATH
java -cp /home/db2inst1/sqllib/java/db2jcc.jar com.ibm.db2.jcc.DB2Jcc -url "jdbc:db2://IP:50001/DBNAME:sslConnection=true;sslCertLocation=/certificate/full/path/certificate.arm;" -user xxxx -password xxxx

java com.ibm.db2.jcc.DB2Jcc -version

-----------------------------------------------------------------execute command as other user (non-loginable)
-- -s /bin/bash overrides nologin and allows to interpret value of -c option
su -s /bin/bash -c "echo ddd" adwdpro   
su -s /bin/bash -c "netstat -tnlp" adwdpro 
su -s /bin/bash -c "lsof -i :46614" adwdpro  

-----------------------------------------------------------------db2top
--in l, then a to give Application Handle id
we can see client pid in 'Client pid:' and client ip and port in '(10.82.46.66 56034]'

-----------------------------------------------------------------test port
-- test if oprt open in linux
telnet ip port
curl -v ip:port
wget -v ip:port
ssh -v -p port ip
-- test if port open in windows
telnet ip port ----- pkgmgr /iu:TelnetClient    -- enable telnet first
tns ip -port port ---- tns is short for Test-NetworkConnection

--test if port is listening, -t : 指明显示TCP端口 -l 只显示listening  -p 显示进程信息
netstat -tap -- in windows and linux
ss -tap | grep 50001
ss -tlp | grep 50001
lsof -i :50000

--test ssl port
openssl s_client -connect IP:50001

-----------------------------------------------------------------dynamic sql
SELECT NUM_EXECUTIONS, AVERAGE_EXECUTION_TIME_S, STMT_SORTS, 
   SORTS_PER_EXECUTION, SUBSTR(STMT_TEXT,1,60) AS STMT_TEXT 
   FROM SYSIBMADM.TOP_DYNAMIC_SQL 
   WHERE STMT_TEXT like '%S_SPTSUM%'
   ORDER BY NUM_EXECUTIONS DESC FETCH FIRST 5 ROWS ONLY

-----------------------------------------------------------------cli bind
--SQL0805N package NULLID.SQLC2H20 was not found https://www.ibm.com/support/pages/sql0805n-package-nullidsqlc2h20-was-not-found

--To check if the package exists in DB Server
  select pkgname from syscat.packages where pkgname like 'SQLC2H20'
  db2 list packages for all | grep SQLC2H20
  
--Resolving the problem requires you to run the bind command from client against the database that you are attempting to connect to. This will install the package in the database. 
--Because several of the utilities supplied with DB2 Connect™ are developed using embedded SQL, they must be bound to an IBM mainframe database server before they can be used with that system.
--It is suggested to bind the package using the below utility list file, db2ubind.lst for Linux, UNIX, and Windows, The bind files are contained in it.
    
1. go to db2 client, and cd /home/db2inst1/sqllib/bnd/ 
2. db2 bind db2clpcs.bnd blocking all grant public collection NULLID
   -- if you don't know specific bind file
   -- db2 bind @db2ubind.lst blocking all grant public collection NULLID

--command to Check the name of the package in the bind file using the ddcspkgn command. 
--bind file could be in db2 client in client server or db2 client in db2 server, it may contains different version, all versions could be installed in DB server
  ddcspkgn /home/db2inst1/sqllib/bnd/db2clpcs.bnd  

--https://datageek.blog/en/2013/09/04/binding-packages/
--Generally, an administrative user will run the bind commands below
db2 bind @db2ubind.lst blocking all grant public
db2 bind @db2cli.lst blocking all grant public
db2 bind db2schema.bnd blocking all grant public sqlerror continue


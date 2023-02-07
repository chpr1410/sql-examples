/****** Query to put logging data into reusable view ******/

create view viewname
AS
SELECT q.* ,
       u.name as created_by_name,
       --ci.name,  --use account.center_location_c instead
       a.center_location_c  as center_name
  FROM table1 q
       INNER JOIN table2 a with(nolock) ON q.id = a.id
       INNER JOIN table3 u with(nolock) ON q.id2 = u.id
 WHERE q.field1 is true
   and a.field2 is true
   and u.field3 is true
 ;
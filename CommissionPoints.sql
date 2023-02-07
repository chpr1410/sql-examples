/****** Query to get call center commission "points" and the relevant metrics ******/

select
u.[name] as 'sched_agent',
u.id as 'sched_agent_id',
isnull(ci.scheduled_lead__c,ci.scheduled_account__c) as 'id',
ci.apt_date__c,
ci.scheduled_time__C,
case when isnull(l.pre_screen__c, a.pre_Screen__c) in ('green','yellow') and isnull(l.lead_segment__C,a.lead_Segment__C) between 4 and 5 then 1
	 when isnull(l.pre_screen__c, a.pre_Screen__c) in ('red','blue (no hit)','Insufficient Information','Not checked','PO Box','Website Down-No Prescreen') and isnull(l.lead_segment__C,a.lead_Segment__C) between 0 and 1 then .25
	 else .5 end as 'points'
into #consults
from
table0 ci
left join table1 u on u.id = ci.Scheduled_by__c
left join table2 l on l.id = ci.Scheduled_Lead__c
left join table3 a on a.Id = ci.Scheduled_Account__c
left join table4 d on d.ActualDate = ci.Apt_Date__c
left join table15 cr on cr.id = ci.Consult_Room__c

where
ci.Arrival_Time__c is not null
and ci.Apt_Date__c >= 'xxxx-xx-xx' 
and cr.Room_Type__c <> 'practice'
and ci.Active__c = 'true'
;
select 
isnull(ah.lead__c,ah.Account__c) as 'id',
ah.CreatedDate,
ah.Action__c,
ah.Notes__c,
u.id as 'cancel_agent'

into #cancels

from table6 ah
left join table7 ci on ci.id = ah.consult_inventory__c
left join table8 u on u.id = ah.CreatedById

where
ah.Action__c = 'cancel' 
and ah.CreatedDate >= '2020-06-01'
and isnull(ah.lead__c,ah.Account__c) is not null
;
select
co.*,
ca.CreatedDate as 'cancel_date'

into #table
from
#consults co
left join #cancels ca on ca.id = co.id and ca.cancel_agent = co.sched_agent_id

where
ca.CreatedDate is null
;
drop table #consults;
drop table #cancels;

select
t.sched_agent,
month(t.Apt_Date__c),
sum(t.points) as 'points'
from
#table t
where month(t.Apt_Date__c) = 11
group by
t.sched_agent,
month(t.Apt_Date__c)


drop table #table;
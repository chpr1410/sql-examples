/* 
Query to get call center commission "points" and the relevant metrics 
Call center agents are compensated ON a commission model.  This model rewards points for each patient that the agent schedules 
Different quality of leads gives the agents different point values.

This query drives a PowerBI dashboard that stakeholders use to monitor/award call center commission
*/


SELECT --consult info and corresponding points
	u.[name] AS  'sched_agent',
	u.id AS  'sched_agent_id',
	isnull(ci.scheduled_lead__c,ci.scheduled_account__c) AS  'id',
	ci.apt_date__c,
	ci.scheduled_time__C,
	CASE WHEN isnull(l.pre_screen__c, a.pre_Screen__c) in ('green','yellow') and isnull(l.lead_segment__C,a.lead_Segment__C) between 4 and 5 THEN 1
		 WHEN isnull(l.pre_screen__c, a.pre_Screen__c) in ('red','blue (no hit)','Insufficient Information','Not checked','PO Box','Website Down-No Prescreen') and isnull(l.lead_segment__C,a.lead_Segment__C) between 0 and 1 THEN .25
		 ELSE .5 END AS  'points'
INTO #consults

FROM
	table0 ci
	left join table1 u ON u.id = ci.Scheduled_by__c
	left join table2 l ON l.id = ci.Scheduled_Lead__c
	left join table3 a ON a.Id = ci.Scheduled_Account__c
	left join table4 d ON d.ActualDate = ci.Apt_Date__c
	left join table15 cr ON cr.id = ci.Consult_Room__c
WHERE
	ci.Arrival_Time__c is not null
	and ci.Apt_Date__c >= 'xxxx-xx-xx' 
	and cr.Room_Type__c <> 'practice'
	and ci.Active__c = 'true'
;

SELECT -- get table of cancels.  Agents aren't awarded points for cancels.  Additionally, agents don't get points for schedules that they made and cancelled in the same day.  
	-- Had a problem with agents 'sniping' other agent's schedules.
	isnull(ah.lead__c,ah.Account__c) AS  'id',
	ah.CreatedDate,
	ah.Action__c,
	ah.Notes__c,
	u.id AS  'cancel_agent'
INTO #cancels
FROM table6 ah
	left join table7 ci ON ci.id = ah.consult_inventory__c
	left join table8 u ON u.id = ah.CreatedById
WHERE
	ah.Action__c = 'cancel' 
	and ah.CreatedDate >= 'xxxx-xx-xx'
	and isnull(ah.lead__c,ah.Account__c) is not null
;

SELECT
	co.*,
	ca.CreatedDate AS  'cancel_date'
INTO #table
FROM
	#consults co
	left join #cancels ca ON ca.id = co.id and ca.cancel_agent = co.sched_agent_id
WHERE
	ca.CreatedDate is null -- Filter out leads that canceled
;

DROP TABLE #consults;
DROP TABLE #cancels;


-- Main results: Agent, appt_date, and points awarded
SELECT
	t.sched_agent,
	month(t.Apt_Date__c),
	SUM(t.points) AS  'points'
FROM
	#table t
GROUP BY
	t.sched_agent,
	month(t.Apt_Date__c)

DROP TABLE #table;

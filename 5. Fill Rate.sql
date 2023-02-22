/* Query to show how full each center is.  Viewing by appointment date over time, allows us to look at fill rate over time */

-- Put consult data into temp table
SELECT
	-- Select consult availability, center info, and appointment slots
	ctr.Name AS 'Center', 
	ctr.id AS 'center_id' ,
    ci.apt_date__c,
	COUNT(ci.Id) AS 'Available_Consults',
	COUNT(ci.id) - 1 AS 'DoubleBookingSlots',
	ci.Apt_Datetime__c,
	cr.[Name] AS 'ConsultRoom',
	DATEPART(HOUR,CAST(ci.Apt_Datetime__c AS time)) AS 'Apt_Hour',
	ctr.Use_Intelligent_Business_Scheduling__c,
	ci.Start_Hour_Int__c
	
INTO #target

FROM
	TABLE_1 ci WITH  (NOLOCK)
	left join TABLE_2 cr WITH  (NOLOCK) ON ci.Consult_Room__c = cr.Id 
	left join TABLE_3 ctr WITH  (NOLOCK) ON cr.Center_Information__c = ctr.Id 

WHERE 
	-- Filter for date range and where room is normal and lead color is appropriate
	ci.apt_date__c >= '2022-01-01' 
	and cr.Room_Type__c = 'Normal' and ci.active__c = 'true'
	and ci.color__c <> 'network purple'

GROUP BY
	-- Group by center, appointment slot, FIS Scheduling, etc
	ctr.Name,  
	ci.apt_date__c,
	ci.Apt_Datetime__c,
	cr.[Name],
	DATEPART(HOUR,CAST(ci.Apt_Datetime__c AS time)),
	ctr.Use_Intelligent_Business_Scheduling__c,
	ctr.id,
	ci.Start_Hour_Int__c
 ;
 
 -- Put Schedule data into temp table
 SELECT
	-- select schedule data by center
	ctr.[name] AS 'center',
	ci.apt_date__c,
	count(isnull(ci.scheduled_lead__c, ci.scheduled_account__c)) AS 'Scheds',
	sum(CASE WHEN isnull(l.Pre_Screen__c, a.Pre_Screen__c) in ('Green','yellow') THEN 1 ELSE  0 END) AS 'gy_scheds'

INTO #scheds

FROM
	TABLE_1 ci
	left join 
	TABLE_2 cr ON cr.id = ci.consult_room__c
	left join 
	TABLE_3 ctr ON ctr.id = cr.center_information__c
	left join 
	TABLE_4 l ON l.id = ci.scheduled_lead__c
	left join
	TABLE_4 a ON a.ConvertedAccountId = ci.scheduled_account__c
 
WHERE
	-- Filter for date range and where room is normal and lead color is appropriate
	ci.apt_date__c >= '2022-01-01'
	and isnull(ci.scheduled_lead__c, ci.scheduled_account__c) is not null
	and cr.room_type__c <> 'Practice'

GROUP BY
	ctr.[name],
	ci.apt_date__c
;

-- Join target and scheds table with the media week and center tables.  Filter/sort by date and center name
SELECT
	ctr.name,
	tar.apt_date__c,
	d.media_week,
	SUM(TargetNum) AS 'target_consults',
	s.Scheds,
	s.gy_scheds

FROM
	-- select specific fields from the target table and group them to join with ci, ctr, and scheds tables
	(SELECT 
		center_id,
		apt_date__c,
		start_hour_int__c,
		SUM(Available_Consults - DoubleBookingSlots) AS 'TargetNum'

		FROM 
			#target

		GROUP BY
			center_id,
			apt_date__c,
			Start_Hour_Int__c
			) tar
	left join TABLE_3 ctr WITH  (NOLOCK) ON tar.center_id = ctr.id 
	left join #scheds s ON s.center = ctr.name and cast(s.apt_date__c AS date) = cast(tar.apt_date__c AS date)
	left join TABLE_5 d ON d.ActualDate = tar.apt_date__c

WHERE
	d.media_week >= '2022-01-01'
	and tar.Apt_Date__c <= '2022-12-31'

GROUP BY
	ctr.name,
	tar.apt_date__c,
	s.scheds,
	s.gy_scheds,
	d.media_week

ORDER BY
	ctr.name

DROP TABLE #target;
DROP TABLE #scheds;
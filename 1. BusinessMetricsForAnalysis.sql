/* 
Query to show business metrics by Lead Segment
Shows % of total, % of Schedules, % of Completed Consults and % of Revenue by Lead Segment
Used to Gauge Model Performance
*/

SELECT 
		l.LeadSegment20__c
		,COUNT(l.LeadSegment20__c) * 100.0 / SUM(COUNT(l.LeadSegment20__c)) OVER() AS lead_percentage
		--,COUNT(s.Lead_Id) AS Schedules
		,COUNT(s.Lead_Id) * 100.0 / SUM(COUNT(s.lead_Id)) OVER() AS sched_percentage
		--,COUNT(c.Lead_Id) AS Completes
		,COUNT(c.Lead_Id) * 100.0 / SUM(COUNT(c.lead_Id)) OVER() AS complete_percentage
		--,SUM(m.revenue_sold) AS Revenue
		,SUM(m.revenue_sold) * 100.0 / SUM(SUM(m.revenue_sold)) OVER() AS rev_percentage
				
FROM 
	TABLE_1 l WITH(NOLOCK)
	LEFT JOIN TABLE_2 m WITH(NOLOCK) ON m.leadid = l.id
	left join (SELECT * from TABLE_3 s WITH(NOLOCK) WHERE  s.AptHistory_Action__c = 'Scheduled' and isnull(s.Lead_Id,s.Account_Id) is not null ) s ON s.Lead_Id = l.Id
	left join TABLE_4 c WITH(NOLOCK) ON c.Lead_Id = s.Lead_Id and s.ConsultInventory_Id = c.ConsultInventory_Id

WHERE l.[LeadSegment20__c] IS NOT NULL
	and l.CreatedDate between '2022-07-01' and '2022-12-31'

GROUP BY
	l.LeadSegment20__c

ORDER BY l.LeadSegment20__c DESC
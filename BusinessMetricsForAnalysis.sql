/****** Script for SelectTopNRows command from SSMS  ******/
SELECT 
      l.Id,
      l.Center__c,
	  l.Lead_Segment__c,
	  l.LeadSegment20__c,
	  l.Pre_Screen__c,

	  case when s.Lead_Id is not null then 1 else 0 end as 'Sched',
	  CASE WHEN c.Lead_Id IS NOT NULL then 1 else 0 end as 'Complete',
	  m.revenue_sold,--Sold revenue 

	  CASE WHEN u.[Name] = 'Kelley Village' then 'Website' WHEN u.[Name] = 'Website API' then 'Website'
			WHEN u.[Name] = 'CCAPI Site Guest User' then 'IMC'
			WHEN u.[Name] = 'Aeris Forrest' then 'CCMS'
			ELSE 'CCMS' 
	  END	as 'CreatedBy_Channel',

	  l.CreatedDate,
      l.LastModifiedDate,
	  c.ConsultInventory_Apt_Date__c --Date of consult
     
  FROM 
  [CCMS].[Salesforce].VW_Lead l with(nolock)
  LEFT JOIN [CCMS].[dbo].VW_Lead_Marketing_Detail m with(nolock) on m.leadid = l.id
  left join (select * from ccms.PowerBI.VW_RPT_Sched s where  s.AptHistory_Action__c = 'Scheduled' and isnull(s.Lead_Id,s.Account_Id) is not null ) s on s.Lead_Id = l.Id
  left join ccms.PowerBI.VW_RPT_FI_Sched c on c.Lead_Id = s.Lead_Id and s.ConsultInventory_Id = c.ConsultInventory_Id
  LEFT JOIN [CCMS].[Salesforce].VW_User u with(nolock) on u.id = l.createdbyid

  WHERE l.[LeadSegment20__c] IS NOT NULL
  --and l.CreatedDate between '2022-07-01' and '2023-02-05'
  and c.ConsultInventory_Apt_Date__c between '2022-07-01' and '2023-02-05'
  --and c.ConsultInventory_Apt_Date__c IS NOT NULL




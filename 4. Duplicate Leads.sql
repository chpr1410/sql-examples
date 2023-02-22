----------------------------------------------------------------------
-- This query populates a PowerBI dashboard that tracks marketing leads
----------------------------------------------------------------------

SELECT 
	/* SELECT date fields */
	m.Lead_Date AS actual_date
	,m.Media_Week AS media_week
	,m.Media_Month AS media_month
	
	/* SELECT center/market fields */
	,CASE WHEN m.center is null THEN 'Partial' ELSE m.center END AS center_name -- Clean for partial leads (leads with no center assigned)
	,dma.name AS market
	,m.In_Market AS in_market
	
	/* SELECT lead type and quality fields */
	,m.Lead_Type AS LeadType -- Traditional or Partial
	,CASE WHEN m.Pre_Screen in ('Green','Yellow','Red') THEN m.Pre_Screen
		WHEN m.Pre_Screen = 'Blue (No Hit)' THEN 'Blue' 
		ELSE 'Other' END AS pre_screen
	
	/* SELECT marketing channel/source/campaign */
	,mi.first_creative_name AS creative
	,mi.first_media_outlet AS media_outlet
	,mi.first_campaign_name AS first_campaign_name
	,mi.last_campaign_name AS last_campaign_name
	,c.Phone_Number__c AS phone_number
	
	,CASE WHEN m.CreatedByName in ('Kelley Village','Website API','Pat Greenwood') THEN 'Website'
		WHEN m.CreatedByName in ('IMC API','CCAPI Site Guest User') THEN 'IMC'
		WHEN m.CreatedByName = 'Aeris Forrest' THEN 'CCMS'
		ELSE 'CCMS-Unknown' END AS CreatedBy_Channel
	
	,CASE WHEN c.Media__c = 'Per Inquiry' THEN 'PI'
		WHEN c.Agency__c = 'CPM Network' THEN 'BX'
		WHEN c.[Type] = 'National' and c.Media__c = 'TV' THEN 'NT'
		WHEN c.[Type] = 'TV' THEN 'LT'
		WHEN c.[Type] = 'Web-Display' THEN 'DIS'
		WHEN c.[Type] = 'Web-SEM' THEN 'SEM'
		ELSE 'Other' END AS campaign_type
	
	/* Engineer Business Metric Fields */
	,COUNT(DISTINCT m.Id) AS leads
	,SUM(CASE WHEN m.In_Market = 'Y' and m.Pre_Screen in ('Green','Yellow') THEN 1 ELSE 0 END) AS GYIM_leads --quality leads in market
	,SUM(mi.num_consult_appointments) AS num_scheds -- schedules
	,SUM(mi.num_consult_completed) AS num_consults -- consults completed
	,SUM(mi.net_num_starts) AS net_starts -- treatment started
	,SUM(ISNULL(mi.collected,0) - ISNULL(mi.refunded,0)) AS net_collected -- net collections
	,SUM(ISNULL(mi.revenue_sold,0) - ISNULL(mi.revenue_cancelled,0)) AS net_sold -- net revenue
	,SUM(CASE WHEN ISNULL(dup.rn,1) = 1 THEN 1 ELSE 0 END) AS ValidLead -- Lead Exists as traditional lead
	,SUM(CASE WHEN ISNULL(dup.rn,1) > 1 THEN 1 ELSE 0 END) AS DuplicateLead -- Lead has been created more than once
	,SUM(CASE WHEN ISNULL(dup.rn,1) > 1 and ISNULL(dup.CreatedByName,'') = 'Website API' THEN 1 ELSE 0 END) AS DuplicateWebLead -- Lead has been created more than once on the website


/* Specify Tables and Joins */
FROM TABLE_1 m WITH(NOLOCK)
LEFT JOIN TABLE_2 c WITH(NOLOCK) ON c.id = m.first_creative_id
LEFT JOIN TABLE_3 mi WITH(NOLOCK) ON m.Id = mi.leadid
LEFT JOIN TABLE_4dma WITH(NOLOCK)on dma.id = mi.dma_name

-- Find way to "join" a field with the number of rows found for a specific lead
LEFT JOIN (	SELECT l.Id, l.CreatedByName,
	ROW_NUMBER() OVER(PARTITION BY isnull(l.FirstName,''), isnull(l.LastName,''), isnull(l.Street,''), isnull(l.PostalCode,''), isnull(l.Phone,''), isnull(l.Email,'') ORDER BY l.Lead_Date) AS rn -- get row number for each partition (each partition gets matching records for a person)
	FROM TABLE_1 l WITH(NOLOCK)
	WHERE Lead_Date >= datefromparts(year(dateadd(month,-24,getdate())),month(dateadd(month,-24,getdate())),1) --within last two years
	and exists (SELECT 1 -- give every row that exists a 1
			FROM TABLE_1 ld WITH(NOLOCK)
			WHERE l.Id <> ld.Id
				and isnull(l.FirstName,'') = isnull(ld.FirstName,'')
				and isnull(l.LastName,'') = isnull(ld.LastName,'')
				and isnull(l.Street,'') = isnull(ld.Street,'')
				and isnull(l.PostalCode,'') = isnull(ld.PostalCode,'')
				and isnull(l.Phone,'') = isnull(ld.Phone,'')
				and isnull(l.Email,'') = isnull(ld.Email,''))
) dup ON m.Id = dup.Id


/* Filter and Group by Lead and Media Fields, as well as the date (leads must be in the last 2 years */
WHERE m.Lead_Date >= datefromparts(year(dateadd(month,-24,getdate())),month(dateadd(month,-24,getdate())),1)      

GROUP BY m.Lead_Date,
	m.Media_Week,
	m.Media_Month,
	CASE WHEN m.center is null THEN 'Partial' ELSE m.center END,
	dma.name,
	CASE WHEN m.Pre_Screen in ('Green','Yellow','Red') THEN m.Pre_Screen 
		WHEN m.Pre_Screen = 'Blue (No Hit)' THEN 'Blue' 
		ELSE 'Other' END,
	m.In_Market,
	mi.first_creative_name,
	mi.first_media_outlet,
	mi.first_campaign_name,
	mi.last_campaign_name,
	c.Phone_Number__c,
	CASE WHEN c.Media__c = 'Per Inquiry' THEN 'PI'
		WHEN c.Agency__c = 'CPM Network' THEN 'BX'
		WHEN c.[Type] = 'National' and c.Media__c = 'TV' THEN 'NT'
		WHEN c.[Type] = 'TV' THEN 'LT'
		WHEN c.[Type] = 'Web-Display' THEN 'DIS'
		WHEN c.[Type] = 'Web-SEM' THEN 'SEM'
		ELSE 'Other' END,
	CASE WHEN m.CreatedByName in ('Kelley Village','Website API','Pat Greenwood') THEN 'Website'
		WHEN m.CreatedByName in ('IMC API','CCAPI Site Guest User') THEN 'IMC'
		WHEN m.CreatedByName = 'Aeris Forrest' THEN 'CCMS'
		ELSE 'CCMS-Unknown' END,
	m.Lead_Type


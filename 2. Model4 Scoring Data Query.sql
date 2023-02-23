WITH 
       QuoteInfo -- Get pricing quotes and treatment type
       AS  (
          SELECT qu.accountId AS  AccountID,
                 COUNT(DISTINCT qu.id) AS  TreatmentsOfferedCount,
                 AVG(qu.Price_Presented_To_Patient__c) AS  AverageCost,
                 MIN(qu.Price_Presented_To_Patient__c) AS  MinimumCost,
                 MAX(qu.Price_Presented_To_Patient__c) AS  MaximumCost,
                 MAX(CASE WHEN o.Treatment_Class__c = 'Double Arch' THEN 1 ELSE 0 END) AS  isDouble,
                 MAX(CASE WHEN o.Treatment_Grade__c = 'Hybrid' THEN 1 ELSE 0 END)      AS  isHybrid,
                 MAX(CASE WHEN o.Treatment_Grade__c = 'Phased' THEN 1 ELSE 0 END)      AS  isPhased,
                 MAX(CASE WHEN o.Treatment_Grade__c not in ('Non-Arch','Zirconia','Hybrid','Phased') THEN 1 ELSE 0 END) AS  isOther
            FROM TABLE_1 qu
                 INNER JOIN TABLE_2 qli WITH(NOLOCK) ON qu.Id = qli.QuoteId  -- 1:many
                 INNER JOIN TABLE_3 p WITH(NOLOCK) ON qli.Product2Id = p.Id  -- 1:1 
                 INNER JOIN TABLE_4 o WITH(NOLOCK) ON p.LegacyTreatmentOption__c = o.Id  -- 1:1
           
	    GROUP BY qu.accountId --individual account
       ),

       TreatmentPlanInfo -- get specific treatment plans and classes
       AS  (
          SELECT tp.Account__c AS  AccountID,
                 COUNT(*) AS  TreatmentsOfferedCount,
                 AVG(tp.Initial_Cost__c) AS  AverageCost,
                 MIN(tp.Initial_Cost__c) AS  MinimumCost,
                 MAX(tp.Initial_cost__c) AS  MaximumCost,
                 MAX(CASE WHEN t.Treatment_Class__c = 'Double Arch' THEN 1 ELSE 0 END) AS  isDouble,
                 MAX(CASE WHEN t.Treatment_Grade__c = 'Hybrid' THEN 1 ELSE 0 END)      AS  isHybrid,
                 MAX(CASE WHEN t.Treatment_Grade__c = 'Phased' THEN 1 ELSE 0 END)      AS  isPhased,
                 MAX(CASE WHEN t.Treatment_Grade__c not in ('Non-Arch','Zirconia','Hybrid','Phased') THEN 1 ELSE 0 END) AS  isOther

            FROM TABLE_5 tp WITH(NOLOCK)
                 LEFT OUTER JOIN TABLE_4 t WITH(NOLOCK) ON tp.Treatment_Option__c = t.Id
           
		   GROUP BY tp.Account__c --individual account
       ),

       CombinedTreatments --combine quote and treatment INTO one.  
	   -- some accounts have info in both treatment_plan/option AND quote.  In these cases, only take FROM quote/quote_line_item
       AS  (
          SELECT * FROM QuoteInfo
			UNION ALL
          SELECT * FROM TreatmentPlanInfo
			WHERE TreatmentPlanInfo.AccountID NOT IN (SELECT AccountID FROM QuoteInfo)
       ),

       ESIperLead -- get ESI for leads
       AS  (
          SELECT Lead__c,
                 MIN(economicStabilityIndicator__c) AS  economicStabilityIndicator -- pull minimum value to be conservative
           FROM TABLE_6
           WHERE Lead__c is not null
           GROUP BY Lead__c
       ),

       AccountLeadInfo -- get account info for leads
       AS  (
          SELECT
                 a.Id                      AS  AccountId,
                 a.CreatedDate AS  CreatedDate,
                 a.Financing_Result__c     AS  FinancingResult,
                 a.Lead_Segment__c         AS  AccountLeadSegment,
                 a.Dental_condition__c     AS  AccountDentalCondition,
                 a.Distance_To_Center__c   AS  AccountDistanceToCenter,
                 l.Id                      AS  LeadID,
                 a.warranty_ID__c          AS  UniqueID,
                 row_number() OVER (partition by a.Id order by l.CreatedDate desc) AS  [rowNumber]  --to take the most recently created lead for the account
           
		   FROM TABLE_7 a
                 left join TABLE_8 l ON l.ConvertedAccountID = a.Id
           
		   WHERE 
             a.recordtypeId = 'xxxxxx' -- Limit to Prospective patients 
             AND a.CreatedDate >= '2020-01-01'  -- Going way back for historical data
             AND a.Model4Tier__c IS NULL -- not scored before
             AND a.warranty_ID__c IS NOT NULL -- because some of them are
       )

-- Output necessary data to score records ON the model
SELECT ai.AccountId,
       ai.CreatedDate,
       ai.UniqueID,
       ai.FinancingResult,
       ai.AccountLeadSegment,
       ai.AccountDentalCondition,
       ai.AccountDistanceToCenter,
       ISNULL(e.economicStabilityIndicator, 14) AS  economicStabilityIndicator,  -- per data prep rules, Nulls (no info) will replaced with an average score
       ti.TreatmentsOfferedCount,
       ti.AverageCost,
       ti.MinimumCost,
       ti.MaximumCost,
       ti.isDouble,
       ti.isArchPlus,
       ti.isArchOnly,
       ti.isNonArch,
       ti.isZirconia,
       ti.isHybrid,
       ti.isPhased,
       ti.isOther,
       ti.isSinusLift,
       ti.isBoneGraftingLift,
       ti.isNightguardLift,
       ti.isImmediateLoadLift,
       0 AS  start -- default value.  Model needs field but it doesn't affect predictions

FROM AccountLeadInfo ai
    inner join CombinedTreatments ti ON ai.AccountId = ti.AccountID
    left outer join ESIperLead e ON ai.LeadID = e.Lead__c

 WHERE ai.rowNumber = 1 -- take only the first (most recently created) record

 ORDER BY ai.CreatedDate DESC
;

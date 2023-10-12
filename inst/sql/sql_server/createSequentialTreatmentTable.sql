IF OBJECT_ID('TEMPDB..#ODTP_SUBJECTS', 'U') IS NOT NULL
	DROP TABLE #ODTP_SUBJECTS;

CREATE TABLE #ODTP_SUBJECTS (
	SUBJECT_ID BIGINT,
	CNT INT
	);

-- FIRST TREATMENTS PATIENTS
INSERT INTO #ODTP_SUBJECTS (
	SUBJECT_ID,
	CNT
	)
SELECT SUBJECT_ID, COUNT(*) AS CNT
FROM @cohortDatabaseSchema.@cohortTable_OSTEOPOROSIS_PATHWAY_ANALYSIS_EVENTS
WHERE PATHWAY_ANALYSIS_GENERATION_ID=1
GROUP BY SUBJECT_ID
HAVING COUNT(*)=1;

-- SECOND-TREATMENT PATIENTS
INSERT INTO #ODTP_SUBJECTS (
	SUBJECT_ID,
	CNT
	)
SELECT SUBJECT_ID, COUNT(*) AS CNT
FROM @cohortDatabaseSchema.@cohortTable_OSTEOPOROSIS_PATHWAY_ANALYSIS_EVENTS
WHERE PATHWAY_ANALYSIS_GENERATION_ID=1
GROUP BY SUBJECT_ID
HAVING COUNT(*)=2;

-- THIRD-TREATMENT PATIENTS
INSERT INTO #ODTP_SUBJECTS (
	SUBJECT_ID,
	CNT
	)
SELECT SUBJECT_ID, COUNT(*) AS CNT
FROM @cohortDatabaseSchema.@cohortTable_OSTEOPOROSIS_PATHWAY_ANALYSIS_EVENTS
WHERE PATHWAY_ANALYSIS_GENERATION_ID=1
GROUP BY SUBJECT_ID
HAVING COUNT(*)=3;


-- ** CREATE SEQUENTIAL TREATMENT TABLE **
IF OBJECT_ID('@cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS', 'U') IS NOT NULL
	DROP TABLE @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS;

CREATE TABLE @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS (
	SUBJECT_ID BIGINT,
	COMBO_ID INT,
	FIRST_START_DATE DATE,
	SECOND_COMBO INT,
	SECOND_START_DATE DATE,
	THIRD_COMBO INT,
	THIRD_START_DATE DATE
);

-- FIRST TREATMENT EVENTS
INSERT INTO @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS (
	SUBJECT_ID,
	COMBO_ID,
	FIRST_START_DATE,
	SECOND_COMBO,
	SECOND_START_DATE,
	THIRD_COMBO,
	THIRD_START_DATE
	)
SELECT T1.SUBJECT_ID, COMBO_ID AS FIRST_COMBO
     , COHORT_START_DATE AS FIRST_START_DATE
     , NULL AS SECOND_COMBO
     , NULL AS SECOND_START_DATE
     , NULL AS THIRD_COMBO
     , NULL AS THIRD_START_DATE
FROM @cohortDatabaseSchema.@cohortTable_OSTEOPOROSIS_PATHWAY_ANALYSIS_EVENTS T1, #ODTP_SUBJECTS T2
WHERE PATHWAY_ANALYSIS_GENERATION_ID=1
  AND T2.CNT=1
  AND T2.SUBJECT_ID=T1.SUBJECT_ID;


-- SECOND TREATMENT EVENTS
INSERT INTO @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS (
	SUBJECT_ID,
	COMBO_ID,
	FIRST_START_DATE,
	SECOND_COMBO,
	SECOND_START_DATE,
	THIRD_COMBO,
	THIRD_START_DATE
	)
SELECT *
FROM (
	SELECT T1.SUBJECT_ID, COMBO_ID AS FIRST_COMBO, COHORT_START_DATE AS FIRST_START_DATE,
	  LEAD(COMBO_ID) OVER (PARTITION BY T1.SUBJECT_ID ORDER BY COHORT_START_DATE) AS SECOND_COMBO,
	  LEAD(COHORT_START_DATE) OVER (PARTITION BY T1.SUBJECT_ID ORDER BY COHORT_START_DATE) AS SECOND_START_DATE
	  , NULL AS THIRD_COMBO
	  , NULL AS THIRD_START_DATE
	FROM @cohortDatabaseSchema.@cohortTable_OSTEOPOROSIS_PATHWAY_ANALYSIS_EVENTS T1, #ODTP_SUBJECTS T2
	WHERE PATHWAY_ANALYSIS_GENERATION_ID=1 AND T2.CNT=2
	  AND T2.SUBJECT_ID=T1.SUBJECT_ID
	) SUB
WHERE SECOND_COMBO IS NOT NULL;


-- THIRD TREATMENT EVENTS
INSERT INTO @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS (
	SUBJECT_ID,
	COMBO_ID,
	FIRST_START_DATE,
	SECOND_COMBO,
	SECOND_START_DATE,
	THIRD_COMBO,
	THIRD_START_DATE
	)
SELECT *
FROM (
SELECT T1.SUBJECT_ID, COMBO_ID AS FIRST_COMBO, COHORT_START_DATE AS FIRST_START_DATE,
  LEAD(COMBO_ID) OVER (PARTITION BY T1.SUBJECT_ID ORDER BY COHORT_START_DATE) AS SECOND_COMBO,
  LEAD(COHORT_START_DATE) OVER (PARTITION BY T1.SUBJECT_ID ORDER BY COHORT_START_DATE) AS SECOND_START_DATE,
  LEAD(COMBO_ID,2) OVER (PARTITION BY T1.SUBJECT_ID ORDER BY COHORT_START_DATE) AS THIRD_COMBO,
  LEAD(COHORT_START_DATE,2) OVER (PARTITION BY T1.SUBJECT_ID ORDER BY COHORT_START_DATE) AS THIRD_START_DATE
FROM @cohortDatabaseSchema.@cohortTable_OSTEOPOROSIS_PATHWAY_ANALYSIS_EVENTS T1, #ODTP_SUBJECTS T2
WHERE PATHWAY_ANALYSIS_GENERATION_ID=1 AND T2.CNT=3
  AND T2.SUBJECT_ID=T1.SUBJECT_ID
) SUB
WHERE THIRD_COMBO IS NOT NULL;


-- ** CREATE Prescription TABLE **
IF OBJECT_ID('@cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS', 'U') IS NOT NULL
	DROP TABLE @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS;

CREATE TABLE @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE INT,
	COMBO INT,
	COHORT_DEFINITION_ID INT,
	SUBJECT_ID BIGINT,
	LAST_VISIT_DATE DATE,
	LINE_START_DATE DATE,
	LINE_END_DATE DATE,
	DRUG_CONCEPT_ID BIGINT,
	DRUG_EXPOSURE_DATE DATE,
	DAYS_SUPPLY INT,
	DURATION INT,
	P_RANK INT
);



-- ALL PRESCRIPTION EVENTS
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 0 AS LINE
	, 0 AS COMBO
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.FIRST_START_DATE AS LINE_START_DATE
			, COHORTS.COHORT_END_DATE AS LINE_END_DATE -- COHORT END DATE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.FIRST_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO IS NULL
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T1.LINE_START_DATE <= T2.COHORT_START_DATE AND T1.COHORT_ID=T2.DRUG_ID;





-- FIRST PRESCRIPTION EVENTS (NO SECOND LINE)
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 1 AS LINE
	, 1 AS COMBO
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.FIRST_START_DATE AS LINE_START_DATE
			, COHORTS.COHORT_END_DATE AS LINE_END_DATE -- COHORT END DATE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.FIRST_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO IS NULL
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T1.LINE_START_DATE <= T2.COHORT_START_DATE AND T1.COHORT_ID=T2.DRUG_ID;


-- FIRST PRESCRIPTION EVENTS (WITH NO COMBO SECOND LINE )
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 1 AS LINE
	, 2 AS COMBO --1ST LINE W/ 2ND LINE (NO COMBO)
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.FIRST_START_DATE AS LINE_START_DATE
			, SUBJECTS.SECOND_START_DATE AS LINE_END_DATE -- SECOND LINE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.FIRST_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO IS NOT NULL AND SUBJECTS.SECOND_COMBO IN (1,2,4,8,16,32,64)
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T2.COHORT_START_DATE >= T1.LINE_START_DATE AND T2.COHORT_START_DATE < T1.LINE_END_DATE  AND T1.COHORT_ID=T2.DRUG_ID;

-- FIRST PRESCRIPTION EVENTS (WITH COMBO SECOND LINE)
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 1 AS LINE
	, 3 AS COMBO --1ST LINE W/ 2ND LINE (COMBO)
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.FIRST_START_DATE AS LINE_START_DATE
			, COHORTS.COHORT_END_DATE AS LINE_END_DATE -- SECOND LINE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.FIRST_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO IS NOT NULL AND SUBJECTS.SECOND_COMBO NOT IN (1,2,4,8,16,32,64)
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T2.COHORT_START_DATE >= T1.LINE_START_DATE AND T2.COHORT_START_DATE <= T1.LINE_END_DATE  AND T1.COHORT_ID=T2.DRUG_ID;

 -- SECOND PRESCRIPTION EVENTS (NO THIRD LINE)
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 2 AS LINE
	, 1 AS COMBO -- 2ND LINE / NO 3rd LINE
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.SECOND_START_DATE AS LINE_START_DATE
			, COHORTS.COHORT_END_DATE AS LINE_END_DATE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.SECOND_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.THIRD_COMBO IS NULL
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T1.LINE_START_DATE <= T2.COHORT_START_DATE

 -- SECOND PRESCRIPTION EVENTS (WITH NO COMBO 2ND LINE)
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 2 AS LINE
	, 2 AS COMBO --2ND LINE W/ 3RD LINE
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.SECOND_START_DATE AS LINE_START_DATE
			, SUBJECTS.THIRD_START_DATE AS LINE_END_DATE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.SECOND_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO IN (1,2,4,8,16,32) AND SUBJECTS.THIRD_COMBO IS NOT NULL
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T2.COHORT_START_DATE >= T1.LINE_START_DATE AND T2.COHORT_START_DATE < T1.LINE_END_DATE;


 -- SECOND PRESCRIPTION EVENTS (WITH NO COMBO 2ND LINE)
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 2 AS LINE
	, 3 AS COMBO --2ND LINE W/ 3RD LINE
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.SECOND_START_DATE AS LINE_START_DATE
			, COHORTS.COHORT_END_DATE AS LINE_END_DATE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.SECOND_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO NOT IN (1,2,4,8,16,32) AND SUBJECTS.THIRD_COMBO IS NOT NULL
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T2.COHORT_START_DATE >= T1.LINE_START_DATE AND T2.COHORT_START_DATE <= T1.LINE_END_DATE;



-- THIRD PRESCRIPTION EVENTS
INSERT INTO @cohortDatabaseSchema.@cohortTable_PRESCRIPTION_EVENTS (
	LINE,
	COMBO,
	COHORT_DEFINITION_ID,
	SUBJECT_ID,
	LAST_VISIT_DATE,
	LINE_START_DATE,
	LINE_END_DATE,
	DRUG_CONCEPT_ID,
	DRUG_EXPOSURE_DATE,
	DAYS_SUPPLY,
	DURATION,
	P_RANK
	)
SELECT 3 AS LINE
	, 1 AS COMBO --2ND LINE W/ 3RD LINE
	, T1.COHORT_DEFINITION_ID
	, T1.SUBJECT_ID
	, LAST_VISIT_DATE
	, LINE_START_DATE
	, LINE_END_DATE
	, T2.DRUG_CONCEPT_ID
	, T2.COHORT_START_DATE AS DRUG_EXPOSURE_DATE
	, T2.DAYS_SUPPLY
	, T2.DURATION*T2.DAYS_SUPPLY AS DURATION,
	ROW_NUMBER() OVER (PARTITION BY T1.COHORT_DEFINITION_ID, T1.COHORT_ID, T1.SUBJECT_ID, T1.LAST_VISIT_DATE, T1.LINE_START_DATE, T1.LINE_END_DATE ORDER BY T2.COHORT_START_DATE DESC) AS P_RANK
FROM (
		SELECT COHORTS.COHORT_DEFINITION_ID
			, RIGHT(COHORT_DEFINITION_ID, 1) AS 'COHORT_ID'
			, SUBJECTS.SUBJECT_ID
			, SUBJECTS.THIRD_START_DATE AS LINE_START_DATE
			, COHORTS.COHORT_END_DATE AS LINE_END_DATE
			, OP.OBSERVATION_PERIOD_END_DATE AS LAST_VISIT_DATE
		FROM @cohortDatabaseSchema.@cohortTable_SUBJECTS_EVENTS SUBJECTS
		JOIN @cohortDatabaseSchema.@cohortTable COHORTS
		ON SUBJECTS.SUBJECT_ID=COHORTS.SUBJECT_ID AND SUBJECTS.THIRD_START_DATE=COHORTS.COHORT_START_DATE
		JOIN @cdmDatabaseSchema.OBSERVATION_PERIOD OP
		ON SUBJECTS.SUBJECT_ID=OP.PERSON_ID
		WHERE COHORTS.COHORT_DEFINITION_ID IN (1001,1002,1003,1004,1005,1006) AND SUBJECTS.SECOND_COMBO NOT IN (1,2,4,8,16,32) AND SUBJECTS.THIRD_COMBO IS NOT NULL
	) T1,
	(SELECT *, RIGHT(COHORT_DEFINITION_ID, 1) AS 'DRUG_ID' FROM @cohortDatabaseSchema.@cohortTable_DRUG) T2
WHERE T1.SUBJECT_ID = T2.SUBJECT_ID AND T2.COHORT_START_DATE >= T1.LINE_START_DATE;
/* ============================================================
   HEALTHCARE CLAIMS RECONCILIATION ANALYSIS PROJECT
   Structure:
     1. Data Setup
     2. Data Quality Validation
     3. Reconciliation — Inpatient
     4. Reconciliation — Outpatient
     5. Root Cause Investigation Queries
     6. Reporting & Analysis
   ============================================================ */


/* ============================================================
   SECTION 1 — DATA SETUP
   Goal: combine inpatient and outpatient claims into a single
   unified table, tagged by claim type, so downstream queries
   don't need to repeat the UNION logic.
   ============================================================ */

DROP TABLE IF EXISTS all_claims;

CREATE TABLE all_claims AS
SELECT
    BeneID,
    ClaimID,
    ClaimStartDt,
    ClaimEndDt,
    Provider,
    InscClaimAmtReimbursed,
    DeductibleAmtPaid,
    AttendingPhysician,
    'Inpatient' AS claim_type
FROM inpatient_claims

UNION ALL

SELECT
    BeneID,
    ClaimID,
    ClaimStartDt,
    ClaimEndDt,
    Provider,
    InscClaimAmtReimbursed,
    DeductibleAmtPaid,
    AttendingPhysician,
    'Outpatient' AS claim_type
FROM outpatient_claims;


/* ============================================================
   SECTION 2 — DATA QUALITY VALIDATION
   Goal: structural sanity checks before trusting the data
   for any downstream analysis.
   ============================================================ */

-- 2.1  Duplicate ClaimIDs (same claim entered more than once)
SELECT
    ClaimID,
    COUNT(*) AS occurrences
FROM all_claims
GROUP BY ClaimID
HAVING COUNT(*) > 1;

-- 2.2  Orphan claims — BeneID not present in the beneficiary table
SELECT DISTINCT
    a.BeneID
FROM all_claims a
LEFT JOIN beneficiary b ON a.BeneID = b.BeneID
WHERE b.BeneID IS NULL;

-- 2.3  Missing or negative reimbursement amounts
SELECT
    ClaimID,
    InscClaimAmtReimbursed
FROM all_claims
WHERE InscClaimAmtReimbursed IS NULL
   OR InscClaimAmtReimbursed < 0;

-- 2.4  Claim end date earlier than start date (any claim type)
SELECT
    ClaimID,
    ClaimStartDt,
    ClaimEndDt
FROM all_claims
WHERE date(ClaimEndDt) < date(ClaimStartDt);

-- 2.5  Inpatient-specific — discharge date earlier than admission date
SELECT
    ClaimID,
    AdmissionDt,
    DischargeDt
FROM inpatient_claims
WHERE date(DischargeDt) < date(AdmissionDt);


/* ============================================================
   SECTION 3 — RECONCILIATION: INPATIENT
   Goal: compare the reported annual inpatient total
   (beneficiary table) against the total recalculated from
   individual claim records (all_claims).
   ============================================================ */

-- 3.1  Full reconciliation table — every beneficiary, Matched or Mismatch
--      (this is the version to export to CSV / Excel)
WITH inpatient_calc AS (
    SELECT
        b.BeneID,
        b.IPAnnualReimbursementAmt AS reported_total,
        IFNULL(SUM(CASE WHEN a.claim_type = 'Inpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS calculated_total
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    BeneID,
    reported_total,
    calculated_total,
    reported_total - calculated_total AS diff,
    CASE
        WHEN reported_total - calculated_total = 0 THEN 'Matched'
        WHEN reported_total - calculated_total > 0 THEN 'Reported > Calculated'
        ELSE 'Calculated > Reported'
    END AS reconciliation_status
FROM inpatient_calc;

-- 3.2  Summary counts — Matched vs Mismatch
WITH inpatient_calc AS (
    SELECT
        b.BeneID,
        b.IPAnnualReimbursementAmt AS reported_total,
        IFNULL(SUM(CASE WHEN a.claim_type = 'Inpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS calculated_total
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    CASE WHEN reported_total - calculated_total = 0 THEN 'Matched' ELSE 'Mismatch' END AS status,
    COUNT(*) AS beneficiary_count
FROM inpatient_calc
GROUP BY status;

-- 3.3  Direction of mismatch — which side is bigger, and how often
WITH inpatient_calc AS (
    SELECT
        b.BeneID,
        b.IPAnnualReimbursementAmt - IFNULL(SUM(CASE WHEN a.claim_type = 'Inpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS diff
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    CASE WHEN diff > 0 THEN 'Reported > Calculated' ELSE 'Calculated > Reported' END AS direction,
    COUNT(*) AS beneficiary_count
FROM inpatient_calc
WHERE diff <> 0
GROUP BY direction;

-- 3.4  Materiality — how big is the mismatch, in aggregate
WITH inpatient_calc AS (
    SELECT
        b.BeneID,
        b.IPAnnualReimbursementAmt - IFNULL(SUM(CASE WHEN a.claim_type = 'Inpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS diff
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    SUM(diff) AS total_gap,
    AVG(diff) AS avg_gap,
    MAX(diff) AS max_gap,
    MIN(diff) AS min_gap
FROM inpatient_calc
WHERE diff <> 0;


/* ============================================================
   SECTION 4 — RECONCILIATION: OUTPATIENT
   Same structure as Section 3, applied to outpatient claims.
   ============================================================ */

-- 4.1  Full reconciliation table
WITH outpatient_calc AS (
    SELECT
        b.BeneID,
        b.OPAnnualReimbursementAmt AS reported_total,
        IFNULL(SUM(CASE WHEN a.claim_type = 'Outpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS calculated_total
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    BeneID,
    reported_total,
    calculated_total,
    reported_total - calculated_total AS diff,
    CASE
        WHEN reported_total - calculated_total = 0 THEN 'Matched'
        WHEN reported_total - calculated_total > 0 THEN 'Reported > Calculated'
        ELSE 'Calculated > Reported'
    END AS reconciliation_status
FROM outpatient_calc;

-- 4.2  Summary counts — Matched vs Mismatch
WITH outpatient_calc AS (
    SELECT
        b.BeneID,
        b.OPAnnualReimbursementAmt AS reported_total,
        IFNULL(SUM(CASE WHEN a.claim_type = 'Outpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS calculated_total
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    CASE WHEN reported_total - calculated_total = 0 THEN 'Matched' ELSE 'Mismatch' END AS status,
    COUNT(*) AS beneficiary_count
FROM outpatient_calc
GROUP BY status;

-- 4.3  Direction of mismatch
WITH outpatient_calc AS (
    SELECT
        b.BeneID,
        b.OPAnnualReimbursementAmt - IFNULL(SUM(CASE WHEN a.claim_type = 'Outpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS diff
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    CASE WHEN diff > 0 THEN 'Reported > Calculated' ELSE 'Calculated > Reported' END AS direction,
    COUNT(*) AS beneficiary_count
FROM outpatient_calc
WHERE diff <> 0
GROUP BY direction;

-- 4.4  Materiality
WITH outpatient_calc AS (
    SELECT
        b.BeneID,
        b.OPAnnualReimbursementAmt - IFNULL(SUM(CASE WHEN a.claim_type = 'Outpatient'
                        THEN a.InscClaimAmtReimbursed END), 0) AS diff
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
)
SELECT
    SUM(diff) AS total_gap,
    AVG(diff) AS avg_gap,
    MAX(diff) AS max_gap,
    MIN(diff) AS min_gap
FROM outpatient_calc
WHERE diff <> 0;


/* ============================================================
   SECTION 5 — ROOT CAUSE INVESTIGATION
   Goal: explain WHY mismatches happen, not just measure them.
   These queries target the minority pattern (Calculated > Reported)
   found in inpatient claims — traced to overlapping/revised
   admission records.
   ============================================================ */

-- 5.1  Detect overlapping/revised inpatient claims:
--      pairs of claims for the same beneficiary, same start date,
--      same provider, but different ClaimID (and usually a
--      different end date) — consistent with a claim being
--      revised/extended while the original record was never removed.
SELECT
    a1.BeneID,
    a1.ClaimID AS claim_1,
    a2.ClaimID AS claim_2,
    a1.ClaimStartDt,
    a1.ClaimEndDt AS end_1,
    a2.ClaimEndDt AS end_2,
    a1.Provider,
    a1.InscClaimAmtReimbursed
FROM inpatient_claims a1
JOIN inpatient_claims a2
    ON a1.BeneID       = a2.BeneID
    AND a1.ClaimStartDt = a2.ClaimStartDt
    AND a1.Provider     = a2.Provider
    AND a1.ClaimID      < a2.ClaimID
ORDER BY a1.BeneID;

-- 5.2  Count how many overlapping pairs exist in total
SELECT COUNT(*) AS overlapping_pairs
FROM inpatient_claims a1
JOIN inpatient_claims a2
    ON a1.BeneID       = a2.BeneID
    AND a1.ClaimStartDt = a2.ClaimStartDt
    AND a1.Provider     = a2.Provider
    AND a1.ClaimID      < a2.ClaimID;

-- 5.3  Cross-check: how many of the "Calculated > Reported"
--      mismatch cases are explained by the overlapping-claims pattern
WITH mismatch_negative AS (
    SELECT b.BeneID
    FROM beneficiary b
    LEFT JOIN all_claims a ON b.BeneID = a.BeneID
    GROUP BY b.BeneID
    HAVING (b.IPAnnualReimbursementAmt
            - IFNULL(SUM(CASE WHEN a.claim_type = 'Inpatient'
                              THEN a.InscClaimAmtReimbursed END), 0)) < 0
),
overlapping_beneficiaries AS (
    SELECT DISTINCT a1.BeneID
    FROM inpatient_claims a1
    JOIN inpatient_claims a2
        ON a1.BeneID       = a2.BeneID
        AND a1.ClaimStartDt = a2.ClaimStartDt
        AND a1.Provider     = a2.Provider
        AND a1.ClaimID      < a2.ClaimID
)
SELECT
    (SELECT COUNT(*) FROM mismatch_negative) AS total_negative_mismatch_cases,
    (SELECT COUNT(*) FROM mismatch_negative m
       JOIN overlapping_beneficiaries o ON m.BeneID = o.BeneID) AS explained_by_overlap;


/* ============================================================
   SECTION 6 — REPORTING & ANALYSIS
   Goal: turn validated, reconciled data into business-usable
   summary reports (regular + ad hoc reporting examples).
   ============================================================ */

-- 6.1  Provider-level summary with review flag
--      (ad hoc report: which providers claim unusually high amounts?)
WITH provider_stats AS (
    SELECT
        Provider,
        COUNT(*)                       AS claim_count,
        SUM(InscClaimAmtReimbursed)    AS total_reimbursed,
        AVG(InscClaimAmtReimbursed)    AS avg_claim_value
    FROM all_claims
    GROUP BY Provider
),
overall_avg AS (
    SELECT AVG(avg_claim_value) AS overall_avg_claim
    FROM provider_stats
)
SELECT
    p.Provider,
    p.claim_count,
    p.total_reimbursed,
    p.avg_claim_value,
    o.overall_avg_claim,
    CASE
        WHEN p.avg_claim_value > 1.5 * o.overall_avg_claim THEN 'Review'
        ELSE 'Normal'
    END AS review_flag
FROM provider_stats p
CROSS JOIN overall_avg o
ORDER BY p.avg_claim_value DESC
LIMIT 20;

-- 6.2  Average length of inpatient stay by diagnosis group
--      (regular report: monitor cost/utilization patterns by diagnosis)
SELECT
    DiagnosisGroupCode,
    COUNT(*) AS claim_count,
    ROUND(AVG(julianday(DischargeDt) - julianday(AdmissionDt)), 1) AS avg_length_of_stay_days
FROM inpatient_claims
GROUP BY DiagnosisGroupCode
ORDER BY avg_length_of_stay_days DESC;

-- 6.3  Monthly claims summary (regular report)
SELECT
    strftime('%Y-%m', ClaimStartDt) AS claim_month,
    claim_type,
    COUNT(*)                        AS claim_count,
    SUM(InscClaimAmtReimbursed)     AS total_reimbursed
FROM all_claims
GROUP BY claim_month, claim_type
ORDER BY claim_month, claim_type;

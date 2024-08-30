SET ANSI_WARNINGS OFF;
SET NOCOUNT ON;

-- Define start and end dates
DECLARE @start_date DATE = '$(StartDate)';
DECLARE @end_date DATE = '$(EndDate)';

-- Create a temporary numbers table for hours
CREATE TABLE #Numbers (Number INT PRIMARY KEY);

-- Populate the numbers table with numbers from 0 to 23 for hours
;WITH Numbers AS (
    SELECT 0 AS Number
    UNION ALL
    SELECT Number + 1
    FROM Numbers
    WHERE Number < 23
)
INSERT INTO #Numbers (Number)
SELECT Number
FROM Numbers
OPTION (MAXRECURSION 0);

-- Create a temporary table for dates
CREATE TABLE #Dates (Date DATE PRIMARY KEY);

-- Populate the dates table with dates between start and end dates
;WITH DateRange AS (
    SELECT @start_date AS Date
    UNION ALL
    SELECT DATEADD(DAY, 1, Date)
    FROM DateRange
    WHERE DATEADD(DAY, 1, Date) <= @end_date
)
INSERT INTO #Dates (Date)
SELECT Date
FROM DateRange
OPTION (MAXRECURSION 0);

-- Generate all dates and hours within the specified range
WITH AllHours AS (
    SELECT 
        d.Date AS [Date],
        RIGHT('0' + CAST(n.Number AS VARCHAR(2)), 2) + ':00' AS [HourDisplay], -- Format as HH:00
        n.Number AS [Hour_24]
    FROM #Dates d
    CROSS JOIN #Numbers n
)
-- Include the header
SELECT 
    'Date' AS [Date],
    'Hour' AS [HOUR],
    'Total Qty. Sold' AS [TOTAL QTY. SOLD],
    'Average Unit Price' AS [AVERAGE UNIT PRICE],
    'Total Sub-Total' AS [TOTAL SUB-TOTAL],
    'Total Discount' AS [TOTAL DISCOUNT],
    'Total Tax' AS [TOTAL TAX]
UNION ALL
-- Actual data
SELECT 
    CONVERT(VARCHAR(10), AH.[Date], 120) AS [Date],
    AH.[HourDisplay] AS [HOUR],
    CAST(ISNULL(SUM(ISNULL(OD.orddet_quantity, 0)), 0) AS VARCHAR(20)) AS [TOTAL QTY. SOLD],
    CASE 
        WHEN COUNT(OD.orddet_quantity) = 0 
        THEN '' 
        ELSE CONVERT(VARCHAR(20), AVG(ISNULL(OD.orddet_unitprice, 0))) 
    END AS [AVERAGE UNIT PRICE],
    CAST(ISNULL(SUM(ISNULL(OD.orddet_totalamount, 0)), 0) AS VARCHAR(20)) AS [TOTAL SUB-TOTAL],
    CAST(ISNULL(SUM(ISNULL(OD.orddet_amountdiscount, 0)), 0) AS VARCHAR(20)) AS [TOTAL DISCOUNT],
    CAST(ISNULL(SUM(ISNULL(OD.orddet_tax, 0)), 0) AS VARCHAR(20)) AS [TOTAL TAX]
FROM 
    AllHours AH
LEFT JOIN 
    OrderDetails OD ON CAST(OD.orddet_datetime AS DATE) = AH.[Date]
                    AND DATEPART(HOUR, OD.orddet_datetime) = AH.[Hour_24]
                    AND OD.orddet_isvoid = 0
GROUP BY 
    AH.[Date],
    AH.[HourDisplay]
ORDER BY 
    [Date];

-- Drop the temporary tables
DROP TABLE #Numbers;
DROP TABLE #Dates;

SET ANSI_WARNINGS ON;
SET NOCOUNT OFF;
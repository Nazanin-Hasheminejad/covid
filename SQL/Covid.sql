/*
People_vaccinated: the number of people who have been received at least one dose
total_vaccinations: the number of vaccinations. For example one person might receive two times vaccinations.
therefore, one unit will be added to the people_vaccinated and two units will be added to total_vaccinations.
*/

--Table which we use for Tableau after all the data proccessing
SELECT iso_code, continent, location, date, population, new_cases, 
	   new_deaths, reproduction_rate, icu_patients, hosp_patients, 
	   weekly_icu_admissions, weekly_hosp_admissions
FROM COVID..COVIDDEATHS

SELECT NEW_DEATHS FROM COVID..CovidDeaths WHERE DATE='8/1/2021' AND LOCATION='Russia'
--------------
SELECT 
	iso_code, continent, location, date, new_tests, new_vaccinations, total_boosters,
	people_vaccinated, people_fully_vaccinated, stringency_index, population_density, 
	median_age, aged_65_older, aged_70_older, cardiovasc_death_rate, diabetes_prevalence,
	female_smokers, male_smokers, handwashing_facilities, hospital_beds_per_thousand, 
	life_expectancy
FROM 
	COVID..COVIDVACCINATIONS

SELECT * FROM COVID..COVIDVACCINATIONS  ORDER BY LOCATION,DATE 
/***********************  CovidDeaths Table   **********************/
/*It is easy to notice that the 'total_cases' column represents the cumulative number of the 'new_cases' column.*/
SELECT 
	LOCATION, DATE, TOTAL_CASES, new_cases 
FROM 
	Covid..CovidDeaths 
ORDER BY 
	LOCATION,DATE


/* According to the data provider's website, the figures in the 'total_cases' column are likely lower than the actual
total number of infected cases. This hypothesis can be investigated using the following query and analyzing its results.

To explore this, we will compile all records where the total deaths have surpassed the total cases reported on that day.
If we find records in this dataset, it will lend credence to the hypothesis. The reasoning behind this is that the total
number of COVID-19 deaths should not exceed the total number of infected individuals unless the reported count of total 
infected cases is less than the actual number.

Utilizing this insight, we can update our dataset. On days where total deaths exceed reported cases, we will replace the
figure in the 'total_cases' column with the number from the 'total_deaths' column, as it represents a more accurate estimate.
However, this adjustment might lead to inconsistencies between the 'total_cases' and 'new_cases' columns since the latter is 
derived from the former. Therefore, we might need to either disregard the 'new_cases' column in our analysis or correct it 
through an appropriate method not covered in this analysis. */
SELECT 
	location,DATE, total_CASES, total_deaths 
FROM 
	Covid..CovidDeaths 
WHERE 
	total_deaths>TOTAL_CASES ORDER BY LOCATION, DATE


--UPDATING THE TABLE
UPDATE 
	Covid..CovidDeaths 
SET 
	TOTAL_CASES = total_deaths 
WHERE 
	total_deaths>TOTAL_CASES


--Now, we are ready to find the death percentage on each date.
SELECT
    LOCATION,
    DATE,
    TOTAL_CASES,
    total_deaths,
    CAST((total_deaths * 100.0 / TOTAL_CASES) AS FLOAT) AS Total_Death_Percentage
FROM
    Covid..CovidDeaths
ORDER BY
    LOCATION,
    DATE;
	
--Adding column 'Total_Death_Percentage' to table 'CovidDeaths'
ALTER TABLE 
	COVID..COVIDDEATHS
ADD Total_Death_Percentage FLOAT


UPDATE
	Covid..CovidDeaths
SET
	 Total_Death_Percentage = CAST((total_deaths * 100.0 / TOTAL_CASES) AS FLOAT)


/* Checking the last date when data was collected for each location.
   '2023-12-31' represents the most recent date for which data was collected for the majority of the locations. */
SELECT 
	LOCATION, MAX(DATE) 
FROM 
	Covid..CovidDeaths 
GROUP BY 
	LOCATION 
ORDER BY 
	MAX(DATE)


/* It seems data were gathered weekely. So it is better to just using the rows with information. */
SELECT * FROM 
	Covid..CovidDeaths
WHERE 
	total_cases IS NOT NULL
ORDER BY 
	LOCATION, DATE

/* Creating a procedure that takes a column name(with type String) as input and sorts the death percentages
for '2023-12-31' in descending order. This table serves as a tool to explore the correlation
between the specified column and death percentages more effectively. */
CREATE PROCEDURE DEATH_CORRELATION_S @STRING_VAR VARCHAR(50) 
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'SELECT ' + QUOTENAME(@STRING_VAR) + ', Total_Death_Percentage ' +
               'FROM Covid..CovidDeaths ' +
               'WHERE DATE = ''2023-12-31'' ' +
               'ORDER BY Total_Death_Percentage DESC';
    EXEC sp_executesql @SQL;
END;


/* Creating a procedure that takes a column name(with type float) as input and sorts the death percentages
for '2023-12-31' in descending order. This table serves as a tool to explore the correlation
between the specified column and death percentages more effectively. */
CREATE PROCEDURE DEATH_CORRELATION_F @FLOAT_VAR VARCHAR(50) 
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'SELECT ' + QUOTENAME(@FLOAT_VAR) + ', Total_Death_Percentage ' +
               'FROM Covid..CovidDeaths ' +
               'WHERE DATE = ''2023-12-31'' ' +
               'ORDER BY Total_Death_Percentage DESC';
    EXEC sp_executesql @SQL;
END;


/* The result of the following query showcases the 'Total_Death_Percentage' on '2023-12-31', which is the latest date from 
the survey conducted in the previous query. The outcome is quite intriguing, revealing a strong correlation between a country's
development and its death percentage. */
EXEC DEATH_CORRELATION_S @STRING_VAR=LOCATION

EXEC DEATH_CORRELATION_F @FLOAT_VAR=POPULATION


/* Retrieving the number of new cases, new deaths, total death percentage, and weekly hospital admissions at the end of each year. 
results show reduction in each of these factors.*/
SELECT
	location, YEAR(DATE) AS Year, AVG(new_cases) AS new_cases, AVG(new_deaths) AS new_deaths, 
	AVG(Total_Death_Percentage) AS Total_Death_Percentage, AVG(weekly_hosp_admissions) AS weekly_hosp_admissions
FROM 
	Covid..CovidDeaths 
WHERE 
	DATE IN (
			SELECT 
				MAX(DATE) 
			FROM 
				Covid..CovidDeaths 
			WHERE 
				TOTAL_CASES IS NOT NULL 
			GROUP BY 
				YEAR(DATE)
			 )
GROUP BY LOCATION,YEAR(DATE)
ORDER BY LOCATION





/***********************  CovidVaccinations Table   **********************/

/*
Description:
The CountBelowThreshold procedure is designed to analyze COVID-19 vaccination data
stored in a database and retrieve distinct values from a specified column where the 
count of occurrences falls below a predefined threshold. This procedure is particularly
useful for identifying locations or categories with insufficient data, such as total
test counts, vaccination counts, or other relevant metrics, in order to prioritize data
collection or monitoring efforts.
*/
CREATE PROCEDURE CountBelowThreshold @COLUMN VARCHAR(50), @THRESHOLD_COLUMN VARCHAR(50)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
				DECLARE @THRESHOLD AS INT=10
				SELECT DISTINCT (' + QUOTENAME(@COLUMN) + ')' +
               ' FROM 
					Covid..CovidVaccinations
               WHERE 
					' + QUOTENAME(@COLUMN) + ' NOT IN ( 
						SELECT 
							DISTINCT(' + QUOTENAME(@COLUMN) + ')
						FROM 
							COVID..COVIDVACCINATIONS
					    WHERE '+
							QUOTENAME(@THRESHOLD_COLUMN) + ' IS NOT NULL AND ' + QUOTENAME(@THRESHOLD_COLUMN) + ' > @THRESHOLD ' +
						'GROUP BY' 
							  + QUOTENAME(@COLUMN) + '
			   ) ' 
    EXEC sp_executesql @SQL;
END

EXEC CountBelowThreshold @COLUMN='LOCATION', @THRESHOLD_COLUMN='total_tests';

EXEC CountBelowThreshold @COLUMN='LOCATION', @THRESHOLD_COLUMN='total_vaccinations';

SELECT * FROM Covid..CovidVaccinations

--I downloaded a dataset about poverty. i have to upload it here and somehow relate it to the covid dataset.
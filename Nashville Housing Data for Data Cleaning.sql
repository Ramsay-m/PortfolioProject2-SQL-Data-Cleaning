--This is a portfolio project meant to demonstrate data cleaning skills.  

-- Creating the table that we'll use


CREATE TABLE PUBLIC.HOUSING(
	UniqueID NUMERIC,
	ParcelID VARCHAR(50),
	LandUse VARCHAR(50),
	PropertyAddress VARCHAR(50),
	SaleDate DATE,
	SalePrice VARCHAR(50),
	LegalReference VARCHAR(50),
	SoldAsVacant VARCHAR(50),
	OwnerName VARCHAR(100),
	OwnerAddress VARCHAR(50),
	Acreage NUMERIC,
	TaxDistrict VARCHAR(50),
	LandValue NUMERIC,
	BuildingValue NUMERIC,
	TotalValue NUMERIC,
	YearBuilt NUMERIC,
	Bedrooms INT,
	FullBath INT,
	HalfBath INT)

-- Import the data
COPY PUBLIC.HOUSING FROM '/Users/ramsay/Documents/Coding/3. SQL Portfolio Project/Part 3 - SQL Data Cleaning/Nashville Housing Data for Data Cleaning.csv' WITH CSV HEADER;

-- Check it 
SELECT * FROM PUBLIC.HOUSING

--- 1. Populate Property Address data
-- Check data
SELECT PropertyAddress
FROM PUBLIC.HOUSING
WHERE PropertyAddress is null

-- There's missing data in the property address column. We can populate it with a reference
-- Since the parcel ID is related to an address, we can use it to populate null address values

--This looks for parcels of land where there are different rows, but the parcel ID is the same, and where one property address is null
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, COALESCE(a.PropertyAddress, b.PropertyAddress)
FROM PUBLIC.HOUSING a
JOIN PUBLIC.HOUSING b
	on a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress is null

-- For properties with the same parcel ID but missing an address value,
-- This takes the updates the property address cell from a row that has it and puts it in a row that doesnt (while making sure the parcel ID is the same) 
-- Note: Coalesce is the Postgresql version of "is null": https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-isnull/#:~:text=If%20the%20expression%20is%20NULL,the%20result%20of%20the%20expression%20.&text=For%20the%20COALESCE%20example%2C%20check%20it%20out%20the%20COALESCE%20function%20tutorial.

UPDATE PUBLIC.HOUSING a
	SET PropertyAddress = COALESCE(a.PropertyAddress, b.PropertyAddress)
	FROM PUBLIC.HOUSING b
	WHERE a.ParcelID = b.ParcelID 
	AND a.UniqueID <> b.UniqueID
	AND a.PropertyAddress is NULL

-- 2. Breaking out Address into individual columns (Address, City, State)
SELECT PropertyAddress
FROM PUBLIC.HOUSING

-- Note: commas are only used as deliminators... so we can use that to spearate
-- using substring (https://www.w3resource.com/PostgreSQL/substring-function.php#:~:text=The%20PostgreSQL%20substring%20function%20is,position%20of%20a%20given%20string.&text=The%20main%20string%20from%20where%20the%20character%20to%20be%20extracted.&text=Optional.,the%20extracting%20will%20be%20starting.)
-- using Position (the postgresql equivilant for CHARINDEX) (https://www.postgresql.org/docs/current/functions-string.html)
-- 2.A) Starting with Property address

SELECT
	SUBSTRING(PropertyAddress, 1, POSITION(',' in PropertyAddress) -1) as Address,
	SUBSTRING(PropertyAddress, POSITION(',' in PropertyAddress) +1, LENGTH(PropertyAddress)) as City
FROM PUBLIC.HOUSING

-- Now making two columns for that
-- One for the street address
ALTER TABLE PUBLIC.HOUSING
 ADD PropertySplitAddress VARCHAR(255);
UPDATE PUBLIC.HOUSING 
 SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, POSITION(',' in PropertyAddress) -1)

-- One for the city
ALTER TABLE PUBLIC.HOUSING
 ADD PropertySplitCity VARCHAR(255);
UPDATE PUBLIC.HOUSING 
 SET PropertySplitCity = SUBSTRING(PropertyAddress, POSITION(',' in PropertyAddress) +1, LENGTH(PropertyAddress))

-- Check it to make sure it worked. 
SELECT *
FROM PUBLIC.HOUSING

-- 2.A) Now doing Owner address ("owneraddress")
-- We're going to use Split part function instead. https://w3resource.com/PostgreSQL/split_part-function.php
-- We're splitting up the address using commas

SELECT 
 split_part(owneraddress, ',', 1),
 split_part(owneraddress, ',', 2),
 split_part(owneraddress, ',', 3)
FROM PUBLIC.HOUSING

-- Now we're adding them to the table as columns

ALTER TABLE PUBLIC.HOUSING
 ADD OwnerSplitaddress VARCHAR(255);
UPDATE PUBLIC.HOUSING 
 SET OwnerSplitaddress =  split_part(owneraddress, ',', 1)


ALTER TABLE PUBLIC.HOUSING
 ADD OwnerSplitCity VARCHAR(255);
UPDATE PUBLIC.HOUSING 
 SET OwnerSplitCity = split_part(owneraddress, ',', 2)
 

ALTER TABLE PUBLIC.HOUSING
 ADD OwnerSplitState VARCHAR(255);
UPDATE PUBLIC.HOUSING 
 SET OwnerSplitState = split_part(owneraddress, ',', 3)
 
-- 3. Change Y and N to Yes and No in "Sold as Vacant" field
-- Show different options in the column

SELECT DISTINCT(soldasvacant)
 FROM PUBLIC.HOUSING

-- There are different options, so we'll make them the same.
-- Out of curiosoty, how many in each group?

SELECT DISTINCT(soldasvacant), COUNT(soldasvacant)
 FROM PUBLIC.HOUSING
 GROUP BY soldasvacant
 ORDER BY 2
 
-- So there are more "Yes" and "No" than "Y" and "N".
-- We'll change the "Ys" and "Ns" to "Yes" and "No"

SELECT soldasvacant
 , CASE when soldasvacant = 'Y' then 'Yes'
    	When soldasvacant = 'N' then 'No'
		ELSE soldasvacant
		END
 FROM PUBLIC.HOUSING
 
-- Now use that to update the table column
UPDATE PUBLIC.HOUSING 
 SET soldasvacant = CASE when soldasvacant = 'Y' then 'Yes'
    	When soldasvacant = 'N' then 'No'
		ELSE soldasvacant
		END
		
-- 4. Remove dublicates
-- Normally, we create a temp table and remove duplicates, but not remove the actual data
-- But here we'll actually delete duplicates

-- This creates a CTE where we can see find rows that have the same values for ParcelID, Property address, etc.


WITH RowNumCTE AS(
SELECT *,
    ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
				 ORDER BY
					UNIQUEID
					) row_num
 FROM PUBLIC.HOUSING

 )

-- This lets us see the duplicates
SELECT *
 FROM RowNumCTE
 WHERE row_num > 1
 ORDER BY PropertyAddress
 
-- Here we're actually deleting the duplicates
-- We can't delete with the CTE in PostgreSQL: https://stackoverflow.com/questions/66434841/how-to-delete-records-from-cte-common-table-expression-in-postgres#:~:text=You%20can%20not%20delete%20record,see%20CTE%20document%20for%20postgresql.&text=Save%20this%20answer.,-Show%20activity%20on
-- Instead, we'll try:

DELETE FROM PUBLIC.HOUSING
WHERE UniqueID IN (
	SELECT
	  	UniqueID
	FROM (
		SELECT
			UniqueID,
			ROW_NUMBER() OVER (PARTITION BY ParcelID,
				 PropertyAddress,
				 SalePrice,
				 SaleDate,
				 LegalReference
					) row_num
		FROM PUBLIC.HOUSING
		) s
	WHERE row_num > 1	
)

-- 5. Delete unused columns
-- We don't typically do this for the raw data, but it's useful for views

ALTER TABLE PUBLIC.HOUSING
  DROP COLUMN OwnerAddress,
  DROP COLUMN taxdistrict,
  DROP COLUMN propertyaddress,
  DROP COLUMN SaleDate;
  

SELECT *
FROM PUBLIC.HOUSING
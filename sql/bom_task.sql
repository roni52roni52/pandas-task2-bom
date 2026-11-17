
USE pandas_bom_task;


-- STEP 3: Calculate annual production
-- Pandas equivalent: calculate_annual_production()
-- Calculate the total quantity produced for each material per year.

CREATE OR REPLACE VIEW annual_production AS
SELECT
    year,
    plant_id,
    produced_material,
    produced_material_release_type,
    produced_material_production_type,
    SUM(produced_material_quantity) AS annual_quantity
FROM (
    -- Remove repeated production records
    -- Production quantities may repeat because materials have multiple components
    SELECT DISTINCT
        year,
        month,
        plant_id,
        produced_material,
        produced_material_release_type,
        produced_material_production_type,
        produced_material_quantity
    FROM bom_raw
) AS production

-- Group monthly production data into annual totals
GROUP BY
    year,
    plant_id,
    produced_material,
    produced_material_release_type,
    produced_material_production_type;


-- STEP 4: Calculate annual component consumption
-- Pandas equivalent: calculate_annual_components()
-- Sum the quantities of components used to produce each material.

CREATE OR REPLACE VIEW annual_components AS
SELECT
    year,
    plant_id,
    produced_material,
    produced_material_release_type,
    produced_material_production_type,
    component_material,
    component_material_release_type,
    component_material_production_type,
    SUM(component_material_quantity) AS annual_consumption
FROM bom_raw

-- Group by year, plant, produced material and component
GROUP BY
    year,
    plant_id,
    produced_material,
    produced_material_release_type,
    produced_material_production_type,
    component_material,
    component_material_release_type,
    component_material_production_type;


-- STEP 5A: Build the material hierarchy
-- Pandas equivalent: the loop inside create_hierarchy()
-- Start with FIN materials and find all their PROD components.

CREATE OR REPLACE VIEW hierarchy AS
WITH RECURSIVE materials AS (

    -- Find the first production component of each finished material
    SELECT
        year,
        plant_id,
        produced_material AS fin_material,
        component_material AS material
    FROM annual_components
    WHERE produced_material_release_type = 'FIN'
      AND component_material_release_type = 'PROD'

    UNION ALL

    -- Find the next production level
    -- Match the previous component with the next produced material
    SELECT
        m.year,
        m.plant_id,
        m.fin_material,
        c.component_material
    FROM materials m

    JOIN annual_components c
        ON m.material = c.produced_material
       AND m.year = c.year
       AND m.plant_id = c.plant_id

    -- Continue only if the next component is another PROD material
    WHERE c.component_material_release_type = 'PROD'
)

-- Remove identical material relationships from the output
SELECT DISTINCT *
FROM materials;


-- STEP 5B: Create the final BoM result
-- Pandas equivalent: create_hierarchy()
-- Combine the hierarchy with annual production and consumption data.

CREATE OR REPLACE VIEW bom_explosion AS
SELECT DISTINCT

    -- Finished material (FIN) information
    h.plant_id AS plant,
    h.fin_material AS fin_material_id,
    'FIN' AS fin_material_release_type,
    f.produced_material_production_type AS fin_material_production_type,
    f.annual_quantity AS fin_production_quantity,

    -- Intermediate production material (PROD) information
    c.produced_material AS prod_material_id,
    c.produced_material_release_type AS prod_material_release_type,
    c.produced_material_production_type AS prod_material_production_type,
    p.annual_quantity AS prod_material_production_quantity,

    -- Component information and annual consumption quantity
    c.component_material AS component_id,
    c.component_material_release_type,
    c.component_material_production_type,
    c.annual_consumption AS component_consumption_quantity,

    -- Reporting year
    h.year

-- Start with the hierarchy created in Step 5A
FROM hierarchy h

-- Find components belonging to each PROD material
-- Match records by material, year and plant
JOIN annual_components c
    ON h.material = c.produced_material
   AND h.year = c.year
   AND h.plant_id = c.plant_id

-- Add the annual production quantity of the FIN material
LEFT JOIN annual_production f
    ON h.fin_material = f.produced_material
   AND h.year = f.year
   AND h.plant_id = f.plant_id

-- Add the annual production quantity of the PROD material
LEFT JOIN annual_production p
    ON c.produced_material = p.produced_material
   AND h.year = p.year
   AND h.plant_id = p.plant_id;


-- VALIDATION: Check the results of the SQL views

-- Check annual production quantities
SELECT * FROM annual_production LIMIT 5;

-- Check annual component consumption
SELECT * FROM annual_components LIMIT 5;

-- Check the production hierarchy for finished material 10000
SELECT *
FROM hierarchy
WHERE fin_material = 10000
ORDER BY material;

-- Check the total number of rows in the final BoM result
SELECT COUNT(*) AS total_rows
FROM bom_explosion;

-- Display a sample of the final 14-column result
SELECT *
FROM bom_explosion
LIMIT 10;

-- Synthetic records for local workflow tests, never Client production content.
INSERT INTO gyms(city_id,slug,name,operator,description,neighbourhood,categories,amenities,source_url,publish_status)
SELECT id,'development-monthly-gym','Development Fixture — Monthly Gym','Development fixtures','Synthetic test record; not a real business.','Test North',ARRAY['BUDGET'],ARRAY['SHOWERS'],'https://fixtures.example.invalid/monthly','PUBLISHED' FROM cities WHERE slug='calgary';
-- statement-breakpoint
INSERT INTO gyms(city_id,slug,name,operator,description,neighbourhood,categories,amenities,source_url,publish_status)
SELECT id,'development-biweekly-gym','Development Fixture — Biweekly Gym','Development fixtures','Synthetic test record; not a real business.','Test South',ARRAY['FULL_SERVICE'],ARRAY['POOL'],'https://fixtures.example.invalid/biweekly','PUBLISHED' FROM cities WHERE slug='calgary';
-- statement-breakpoint
INSERT INTO gym_pricing(gym_id,plan_name,recurring_cents,billing_frequency,mandatory_annual_fee_cents,initiation_fee_cents,pricing_complete,source_url)
SELECT id,'Development fixture monthly plan',2500,'MONTHLY',0,0,true,'https://fixtures.example.invalid/pricing' FROM gyms WHERE slug='development-monthly-gym';
-- statement-breakpoint
INSERT INTO gym_pricing(gym_id,plan_name,recurring_cents,billing_frequency,mandatory_annual_fee_cents,initiation_fee_cents,pricing_complete,source_url)
SELECT id,'Development fixture biweekly plan',1200,'BIWEEKLY',6000,3000,true,'https://fixtures.example.invalid/pricing' FROM gyms WHERE slug='development-biweekly-gym';
-- statement-breakpoint
INSERT INTO gym_pricing(gym_id,plan_name,recurring_cents,billing_frequency,pricing_complete,source_url)
SELECT id,'Development fixture incomplete plan',0,'MONTHLY',false,'https://fixtures.example.invalid/pricing' FROM gyms WHERE slug='development-biweekly-gym';
-- statement-breakpoint
INSERT INTO clubs(city_id,slug,name,sport,description,tags,source_url,publish_status)
SELECT id,'development-running-club','Development Fixture — Running Club','Running','Synthetic club for workflow testing.',ARRAY['DEVELOPMENT_FIXTURE'],'https://fixtures.example.invalid/club','PUBLISHED' FROM cities WHERE slug='calgary';
-- statement-breakpoint
INSERT INTO events(city_id,slug,name,organizer,description,start_at,location,sport,tags,source_url,publish_status)
SELECT id,'development-running-event','Development Fixture — Running Event','Development fixtures','Synthetic event for workflow testing.',now()+interval '14 days','Development test venue','Running',ARRAY['DEVELOPMENT_FIXTURE'],'https://fixtures.example.invalid/event','PUBLISHED' FROM cities WHERE slug='calgary';

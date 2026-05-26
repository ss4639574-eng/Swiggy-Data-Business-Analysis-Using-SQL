use swiggy_db;

-- create table schema -- 

create table restaurant_orders (
    
	state varchar(50) not null,
    city varchar(50) not null,
    order_date varchar(255),
    restaurant_name varchar(255) ,
    location varchar(50),
    category varchar(50),
    dish_name varchar(255) not null,
    pric_INR Decimal(10,2),
    rating Decimal(2,1),
    rating_count int default 0 
    );

-- loading data by syntax --

set global local_infile = 1;
load data local infile 'E:/sagar material/Source/Swiggy_Data.csv' 
into table restaurant_orders fields terminated by ','
optionally enclosed by '"'
lines terminated by '\n'
ignore 1 rows;

-- fixing date error --

update restaurant_orders
set order_date = str_to_date(replace(order_date,'/','-'),'%d-%m-%Y') ;

alter table restaurant_orders modify order_date date;

-- data validation & cleaing
-- Null check table

select 
sum(case when state is null then 1 else 0 end) as null_state,
sum(case when city is null then 1 else 0 end) as null_city,
sum(case when order_date is null then 1 else 0 end) as null_state,
sum(case when restaurant_name is null then 1 else 0 end) as null_restaurant,
sum(case when location is null then 1 else 0 end) as null_location,
sum(case when category is null then 1 else 0 end) as null_category,
sum(case when dish_name is null then 1 else 0 end) as null_dish,
sum(case when pric_INR is null then 1 else 0 end) as null_price,
sum(case when rating is null then 1 else 0 end) as null_rating,
sum(case when rating_count is null then 1 else 0 end) as null_rating_count
from restaurant_orders;

-- Blank or empty strings
select * from restaurant_orders
where state = '' or city = '' or restaurant_name = '' or category = ''or dish_name = '' ;

-- Duplicate detection 
select state,city,order_date,restaurant_name,location,category,dish_name,
pric_INR,rating,rating_count,count(*) as CNT
from restaurant_orders
group by state,city,order_date,restaurant_name,location,category,dish_name,
pric_INR,rating,rating_count
having count(*) > 1;

-- Delete Duplication
alter table restaurant_orders add column id int auto_increment primary key ;

delete from restaurant_orders 
where id not in ( select min_id from (
    select min(id) as min_id
    from restaurant_orders
    group by state,city,order_date,restaurant_name,location,category,dish_name,
pric_INR,rating,rating_count
) as tmp
);


-- Creating Schema
-- Dimension Tables
-- Date table

create table dim_date (
date_id int auto_increment primary key ,
full_date Date ,
`year` int ,
`Quarter` int ,
`month` int,
month_name varchar(20),
`day` int,
`week` int
) ;

-- dim_location 

create table dim_location (
location_id int auto_increment primary key ,
state varchar(100),
city varchar(100) ,
location varchar(200)
);

-- dim_restaurant

create table dim_restaurant (
restaurant_id int auto_increment primary key,
restaurant_name varchar(200)
);

-- dim_category

create table dim_category (
category_id int auto_increment primary key,
category varchar(200)
);

-- dim_dish
create table dim_dish (
dish_id int auto_increment primary key ,
dish_name varchar(200)
);

-- Fact Table
create table fact_swiggy_orders (
order_id int auto_increment primary key,

date_id int,
price_INR decimal(10,2),
rating decimal(4,2),
rating_count int,

location_id int ,
restaurant_id int,
category_id int,
dish_id int,

foreign key (date_id) references dim_date(date_id),
foreign key (location_id) references dim_location(location_id),
foreign key (category_id) references dim_category(category_id),
foreign key (restaurant_id) references dim_restaurant(restaurant_id),
foreign key (dish_id) references dim_dish(dish_id)
);


-- Insert data in tables
-- dim date 
insert into dim_date (full_date,`year`,`month`,month_name,`Quarter`,`day`,`week`)
select distinct
   order_date,
   year(order_date),
   month(order_date),
   monthname(order_date),
   Quarter(order_date),
   day(order_date),
   week(order_date)
   from restaurant_orders
   where order_date is not null ;
   
-- dim location
  insert into dim_location (state,city,location)
  select distinct
      state, city, location 
      from restaurant_orders;
      
-- dim category
insert into dim_category(category)
select distinct category
from restaurant_orders;

-- dim dish
insert into dim_dish(dish_name)
select distinct dish_name 
from restaurant_orders;

-- dim restaurant
insert into dim_restaurant(restaurant_name)
select distinct restaurant_name
from restaurant_orders; 

-- fact table

insert into fact_swiggy_orders (
     date_id,
     price_INR,
     rating,
     rating_count,
     location_id,
     restaurant_id,
     category_id,
     dish_id
)
select 
  dd.date_id,
  r.pric_INR,
  r.rating,
  r.rating_count,
  dl.location_id,
  dr.restaurant_id,
  dc.category_id,
  dsh.dish_id
  from restaurant_orders as r
  
  join dim_date as dd
  on dd.full_date = r.order_date
  
  join dim_location as dl
  on dl.state = r.state
  and dl.city = r.city
  and dl.location = r.location
  
  join dim_restaurant as dr
  on dr.restaurant_name = r.restaurant_name
  
  join dim_category as dc
  on dc.category = r.category
  
  join dim_dish as dsh
  on dsh.dish_name = r.dish_name ;

select * from fact_swiggy_orders;

select * from fact_swiggy_orders as f
join dim_date as dd on f.date_id = dd.date_id
join dim_location as dl on f.location_id = dl.location_id
join dim_restaurant as dr on f.restaurant_id = dr.restaurant_id
join dim_category as dc on f.category_id = dc.category_id
join dim_dish as dsh on f.dish_id = dsh.dish_id;


-- KPI's
-- total orders

select count(order_id) as total_orders from fact_swiggy_orders ;

-- Total revenue (INR million)

select concat(format(sum(price_INR)/1000000,2), ' ', 'INR million') as total_revenue
from fact_swiggy_orders;

-- avgerage dish price
 
 select concat(format(avg(price_INR),2), ' ', 'INR') as total_revenue
from fact_swiggy_orders;

-- average rating

select 
  avg(rating) as avg_rating
  from fact_swiggy_orders;
  
-- deep-dive Business analysis

-- Monthly order trends

select d.year,d.month,d.month_name,
  count(*) as total_orders
  from fact_swiggy_orders as f
  join dim_date as d 
  on f.date_id = d.date_id
  group by d.year,d.month,d.month_name 
  order by count(*) desc;
  
  -- Quarter trend
  select d.year,d.Quarter,
  count(*) as total_orders
  from fact_swiggy_orders as f
  join dim_date as d
  on f.date_id = d.date_id
  group by d.year,d.Quarter
  order by count(*) desc;
  
  -- year trends
  
    select d.year,
  count(*) as total_orders
  from fact_swiggy_orders as f
  join dim_date as d
  on f.date_id = d.date_id
  group by d.year
  order by count(*) desc;
  
  -- orders by day of week (Mon-sun)
  select 
    dayname(d.full_date) as day_name,
    count(*) as total_orders
    from fact_swiggy_orders as f
    join dim_date as d
    on f.date_id = d.date_id
    group by dayname(d.full_date),weekday(d.full_date)
    order by weekday(d.full_date);
    
    -- Top 10 cities by order volume
    
    select l.city,
      count(*) as total_orders
      from fact_swiggy_orders as f 
      join dim_location as l
      on f.location_id = l.location_id
      group by l.city
      order by count(*) desc
      limit 10;
      
-- Revenue contribution by states
select l.state,
sum(f.price_INR) as total_revenue 
from fact_swiggy_orders as f
join dim_location as l
on f.location_id = l.location_id
group by l.state
order by sum(f.price_INR) desc;

-- top 10 restaurant by orders

 select r.restaurant_name,
	count(*) as total_orders
      from fact_swiggy_orders as f 
      join dim_restaurant as r
      on f.restaurant_id = r.restaurant_id
      group by r.restaurant_name
      order by count(*) desc
      limit 10;
      
-- Top category by order volume
select 
    c.category,
    count(*) as total_orders
    from fact_swiggy_orders as f
    join dim_category as c
    on f.category_id = c.category_id
    group by c.category
    order by total_orders desc;
    
-- Most orders dish

select d.dish_name,
count(*) as total_orders
from fact_swiggy_orders as f
join dim_dish as d
on f.dish_id = d.dish_id
group by d.dish_name
order by total_orders desc
limit 10;

-- cusinie performance ( orders + avg rating)

select
  c.category,
  count(*) as total_orders,
  avg(format(f.rating,2)) as avg_rating
  from fact_swiggy_orders as f
  join dim_category as c
  on f.category_id = c.category_id
  group by c.category
  order by total_orders desc;
  
  
-- Total orders by price range

select 
     case
         when cast(price_INR as decimal(10,2)) < 100 then 'under 100'
         when cast(price_INR as decimal(10,2))  between 100 and 199  then '100-199'
         when cast(price_INR as decimal(10,2))  between 200 and 299  then '200-299'
         when cast(price_INR as decimal(10,2))  between 300 and 399  then '300-499'
         else '500+'
	 end as price_range,
     count(*) as total_orders
     from fact_swiggy_orders
     group by price_range
     order by total_orders desc;

-- Rating count distributiob (1-5)

select 
    rating,
    count(*) as rating_count
    from fact_swiggy_orders
    group by rating
    order by rating desc;
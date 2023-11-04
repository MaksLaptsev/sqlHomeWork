-- Вывести к каждому самолету класс обслуживания и количество мест этого класса

select (aircrafts_data.model::jsonb->'ru') model_airplane,s.fare_conditions,count(s.seat_no)from aircrafts_data
inner join seats s on aircrafts_data.aircraft_code = s.aircraft_code
    group by model_airplane, s.fare_conditions
    order by model_airplane;

-- Найти 3 самых вместительных самолета (модель + кол-во мест)

select (aircrafts_data.model::jsonb->'ru') model,count(s.seat_no) counts_of_seats from aircrafts_data
inner join seats s on aircrafts_data.aircraft_code = s.aircraft_code
    group by aircrafts_data.model
    order by counts_of_seats  DESC limit 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

select aircrafts_data.aircraft_code, (aircrafts_data.model::jsonb->'ru') model_airplane,
       s.seat_no from aircrafts_data
inner join seats s on aircrafts_data.aircraft_code = s.aircraft_code
    where aircrafts_data.model::jsonb->>'ru' = 'Аэробус A321-200'
        and s.fare_conditions != 'Economy'
    group by aircrafts_data.aircraft_code,model_airplane, s.seat_no
    order by s.seat_no;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

select a.airport_code, a.airport_name::jsonb->'ru' aiport_name,a.city::jsonb->'ru' city_name from (
    select city from airports_data
        group by city
        having count(airport_code) > 1
    )as cities
inner join airports_data as a on cities.city = a.city;


-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

select * from flights
where flights.departure_airport in (
    select airports_data.airport_code as code from airports_data
        where airports_data.city::json->>'ru' = 'Екатеринбург'
        group by code
    ) and
        flights.arrival_airport in (
        select airports_data.airport_code as code from airports_data
            where airports_data.city::json->>'ru' = 'Москва'
            group by code
    ) and
        flights.status in ('Scheduled', 'On Time', 'Delayed')
    and flights.scheduled_departure > bookings.now()
order by flights.scheduled_departure limit 1;

-- Вывести самый дешевый и дорогой билет и стоимость ( в одном результирующем ответе)

select b.ticket_no, b.book_ref, b.passenger_id, b.passenger_name,a.flight_id,a.fare_conditions,a.amount from (
      (select ticket_no,flight_id,fare_conditions,amount from ticket_flights
            where amount = (select max(amount)from ticket_flights)
            limit 1) union
      (select ticket_no,flight_id,fare_conditions,amount from ticket_flights
            where amount = (select min(amount)from ticket_flights)
            limit 1)
      )a, tickets b
where b.ticket_no = a.ticket_no;

-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов

select tf.flight_id,f.flight_no,f.scheduled_departure,f.scheduled_arrival,
       f.departure_airport,f.arrival_airport,f.status,f.aircraft_code,
       f.actual_departure,f.actual_arrival, sum(amount) as totalsum  from ticket_flights tf
inner join flights f on f.flight_id = tf.flight_id
    group by tf.flight_id,f.flight_no,f.scheduled_departure,f.scheduled_arrival,
             f.departure_airport,f.arrival_airport,f.status,f.aircraft_code,
             f.actual_departure,f.actual_arrival
    order by totalsum DESC limit 1;

-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

select ad.aircraft_code, ad.model::jsonb->'ru' model_airplane, ad.range, t.totalsum from aircrafts_data ad
inner join (
    select tf.flight_id,f.aircraft_code, sum(amount) as totalsum  from ticket_flights tf
    inner join flights f on f.flight_id = tf.flight_id
    group by tf.flight_id,f.aircraft_code
    order by totalsum DESC limit 1
) as t on t.aircraft_code = ad.aircraft_code;

-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город

with t as(
    select f.aircraft_code, f.arrival_airport,
           count(f.aircraft_code) as total,
           row_number() over (partition by f.aircraft_code order by count(*) desc ) as rows
    from flights f
    group by f.aircraft_code,f.arrival_airport
)select total,ad.aircraft_code, ad.model::jsonb->'ru' model_airplane,
        apd.airport_name::jsonb->'ru' airport, apd.city::jsonb->'ru' city_name
from t
    inner join aircrafts_data ad on t.aircraft_code = ad.aircraft_code
    inner join airports_data apd on t.arrival_airport = apd.airport_code
where rows = 1;

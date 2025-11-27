/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Щербань Сергей
 * Дата: 18-05-25
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
work AS (
SELECT *, 
CASE
WHEN city_id='6X8I' THEN 'Санкт-Петербург'
ELSE 'ЛенОбл'
END AS region,
CASE
WHEN days_exposition <= 30 THEN '2-до месяця'
WHEN days_exposition <= 90 THEN '3-до трех месяцев'
WHEN days_exposition <= 180 THEN '4-до полугода'
WHEN days_exposition >= 181 THEN '5-более полугода'
ELSE '1-активные'
END AS activity
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
LEFT JOIN real_estate.type USING (type_id)
LEFT JOIN real_estate.city USING (city_id)
WHERE id IN (SELECT * FROM filtered_id) AND type_id='F8EM'
)
-- Основной запрос
SELECT 
region,
activity,
COUNT(id) AS total_adv,
ROUND(AVG(last_price/total_area)::NUMERIC,-2) AS avg_meter_cost,
ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS avg_rooms,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS avg_balcony,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS avg_floor,
ROUND((AVG(is_apartment)*100),2) AS apartment_share,
ROUND(AVG(ceiling_height)::NUMERIC,2) AS avg_height
FROM work
GROUP BY region, activity
ORDER BY region DESC, activity;


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Подготовка
data AS (
SELECT
*,
first_day_exposition + (days_exposition * INTERVAL'1 day') AS last_day_exposition,
DATE_TRUNC('year',first_day_exposition::DATE) AS year
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
WHERE id IN (SELECT * FROM filtered_id) AND type_id = 'F8EM'
),
data_filtr AS (
SELECT 
*,TO_CHAR(first_day_exposition, 'Month') AS month_name_first,
--EXTRACT (month FROM first_day_exposition) AS month_first,
TO_CHAR(last_day_exposition, 'Month') AS month_name_last,
--EXTRACT (month FROM last_day_exposition) AS month_last,
NTILE (12) OVER (ORDER BY days_exposition) AS rank_exposition
FROM data
WHERE year <> '2019-01-01' AND year <> '2014-01-01'
),
data_first AS (
SELECT
month_name_first,
COUNT(id) AS count_advertisement_first,
ROUND(AVG(last_price/total_area)::NUMERIC,-1) AS avg_meter_cost_first,
ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area_first
FROM data_filtr
GROUP BY month_name_first
ORDER BY month_name_first
),
data_last AS (
SELECT 
month_name_last, 
COUNT(id) AS count_advertisement_last,
ROUND(AVG(last_price/total_area)::NUMERIC,-1) AS avg_meter_cost_last,
ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area_last
FROM data_filtr
WHERE month_name_last IS NOT NULL
GROUP BY month_name_last
ORDER BY month_name_last
)
--  Основной запрос
SELECT 
*,
NTILE (12) OVER (ORDER BY count_advertisement_first DESC) AS rank_exposition_first
FROM data_first AS f 
FULL JOIN data_last AS l ON f.month_name_first=l.month_name_last
ORDER BY rank_exposition_first;


-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
work AS (
SELECT *
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
LEFT JOIN real_estate.type USING(type_id)
LEFT JOIN real_estate.city USING (city_id)
WHERE id IN (SELECT * FROM filtered_id) AND city_id<>'6X8I' 
),
sheres AS (
 SELECT
      city,
      COUNT(id) AS ended_adv
    FROM work
    WHERE days_exposition IS NOT NULL
    GROUP BY city
)
-- go
SELECT 
city,
COUNT(id) AS total_adv,
ROUND(ended_adv::numeric/COUNT(id),2) AS closed_adv_sheres,
ROUND(AVG(total_area)::NUMERIC,2) AS avg_total_area,
ROUND(AVG(last_price/total_area)::NUMERIC,-2) AS avg_meter_cost,
ROUND(MIN(last_price/total_area)::NUMERIC,-2) AS min_meter_cost,
ROUND(MAX(last_price/total_area)::NUMERIC,-2) AS max_meter_cost,
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_exposition) AS avg_days_exposition
FROM work
LEFT JOIN sheres USING (city)
GROUP BY city,ended_adv
HAVING count (id) > 50
ORDER BY total_adv DESC, city;
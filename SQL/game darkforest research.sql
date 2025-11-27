/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: ЩЕРБАНЬ СЕРГЕЙ БОРИСОВИЧ
 * Дата: 01.05.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT
    COUNT(payer) AS total_users,
    SUM(payer) AS payers,
    ROUND(AVG(payer), 4) AS payers_share
FROM fantasy.users u;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT
    r.race,
    COUNT(u.id) AS users,
    SUM(u.payer) AS payers,
    ROUND(AVG(u.payer), 4) AS share
FROM fantasy.users u
LEFT JOIN fantasy.race r
USING (race_id)
GROUP BY 1
ORDER BY 4 DESC, 3 DESC

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT
	COUNT(transaction_id) AS total_paying,
	SUM(amount) AS total_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount) AS avg_amount,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana,
	STDDEV(amount) AS stand_dev
FROM 
	fantasy.events;

-- 2.2: Аномальные нулевые покупки:

SELECT COUNT(transaction_id) AS count_pay,
       COUNT(transaction_id) FILTER (WHERE amount = 0) AS count_null_pay,
       COUNT(transaction_id) FILTER (WHERE amount = 0) / COUNT(*)::FLOAT AS percent_pay
FROM fantasy.events e

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

SELECT
    payer,
    COUNT(id) AS total_users,
    ROUND(AVG(total_orders::NUMERIC), 2) AS avg_num_transaction_user,
    ROUND(AVG(sum_amount::NUMERIC), 2) AS avg_sum_transaction_user
FROM (
    -- Подсчитаем статистику по игрокам
    SELECT
        u.id, 
        CASE 
    	WHEN payer = 1 THEN 'pay_to_play'
    	WHEN payer = 0 THEN 'free_to_play'
  	END AS payer,
        COUNT(*) AS total_orders,
        COALESCE(SUM(amount), 0) AS sum_amount -- для игроков без покупок ставим 0
    FROM fantasy.users AS u
    LEFT JOIN (SELECT * FROM fantasy.events WHERE amount <> 0) AS e USING (id)
    GROUP BY u.id, payer) subq
GROUP BY payer;

-- 2.4: Популярные эпические предметы:

WITH item_populations AS
(
	SELECT
		game_items, 
        item_code,            
        COUNT(item_code) AS total_sales,  
        COUNT(DISTINCT id) AS paying_users
    FROM
        fantasy.items
    LEFT JOIN
    	fantasy.events USING(item_code)
    WHERE
        amount > 0  
    GROUP BY
        item_code,
		game_items
			)
SELECT
    game_items,
    total_sales,
	ROUND(total_sales / (SELECT SUM(total_sales::NUMERIC) FROM item_populations), 2) AS portion_sales,  
	ROUND(paying_users / (SELECT COUNT(DISTINCT id)::numeric FROM fantasy.events WHERE amount > 0), 2) AS portion_paying_users 
FROM
    item_populations
GROUP BY
	game_items,
	total_sales,
	paying_users
ORDER BY 
	portion_sales DESC,
	portion_paying_users DESC,
	total_sales DESC,
	game_items;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

WITH total_players AS 
(
	SELECT
		race,
		COUNT(id) AS total_users
	FROM
		fantasy.users
	JOIN
		fantasy.race USING (race_id)
	GROUP BY
		race
			),
paying_players AS 
(
	SELECT
		race,
		COUNT(DISTINCT id) AS paying_users,
		SUM(amount) AS total_amount,
		AVG(amount) AS avg_total_amount,
		COUNT(*) AS total_orders
	FROM
		fantasy.users
	JOIN
		fantasy.race USING (race_id)
	JOIN
		fantasy.events USING (id)
	WHERE
		amount > 0
	GROUP BY
		race
    		),
buyers AS 
(
	SELECT
		race,
		COUNT(DISTINCT id) AS buyers
	FROM
		fantasy.users
	JOIN
		fantasy.race USING (race_id)
	JOIN
		fantasy.events USING (id)
	WHERE
		payer > 0
	GROUP BY
		race
			)
SELECT
	total_players.race,
	total_users,
	paying_users,
	ROUND(paying_users::numeric / total_users, 2) AS percentage_paying_users,
	ROUND(buyers::numeric / paying_users, 2) AS share_paying_among_buyers,
	ROUND(total_orders::numeric / paying_users, 2) AS avg_orders_per_user,
	ROUND(avg_total_amount::numeric, 2) AS avg_amount_per_order,
	ROUND(total_amount::numeric / paying_users, 2) AS avg_amount_per_user
FROM
	total_players
LEFT JOIN
	paying_players USING(race)
LEFT JOIN
	buyers USING(race);

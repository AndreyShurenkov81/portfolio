/**************************
* Автор: Andrey Shurenkov
* Код Oracle
*
* Примеры реализации Slowly Changing Dimensions: scd1, scd2 на данных из таблицы agrmnt. 
* Для создание табилцы agrmnt и заполнение ее тестовыми данными необходимо выполнить скрипт dataset.sql.
***************************/

/*
 * Подготовка данных после того как выполнили скрипт dataset.sql
 * 
 * Небходимо выполнить все 3 пункта
 */

-- 1. Создаем таблицу источник agrmnt_source с данными изтаблицы agrmnt для последующего обновления целевой таблицы agrmnt_target
begin
	execute immediate 'drop table sandbox.agrmnt_source';
exception
	when others then null;
end;

create table sandbox.agrmnt_source as 
select	row_number() over (order by agrmnt, period) id,
		agrmnt,
		start_year,
		period,
		agrmnt_sum,
		type_operation
from sandbox.agrmnt a;

-- 2. Меняем часть данных в agrmnt_source
update sandbox.agrmnt_source set agrmnt_sum = agrmnt_sum-500
where mod(id,2) = 1;

-- 3. Добавляем новые записи в agrmnt_source
insert into sandbox.agrmnt_source
with 
	tmp_id as (select max(id) as id from sandbox.agrmnt_source),
	tmp_agrmnt as (	select 	b.id+row_number() over (order by agrmnt, period) as id,
							regexp_replace(agrmnt,'001/','003/',1,1) as agrmnt,
							start_year,
							period,
							round(dbms_random.value(1000,2000)) as agrmnt_sum,
							type_operation
					from sandbox.agrmnt a
					cross join tmp_id b
					where a.agrmnt = (select max(agrmnt) from sandbox.agrmnt a))
select 	ta.*
from tmp_agrmnt ta;

/*
 * Пример реализации scd1 через exchange partition
 * 
 * таблица agrmnt_target - целевая таблица
 * таблица agrmnt_target_tmp - таблица с новыми данными
 * 
 * Требование к алгоритму
 * 1. Обновление целевой таблицы без delete старых данных
 * 
 * Перед выполнением выполнить блок "Подготовка данных"
 */

-- Создаем целевую партиционированную таблицу
begin
	execute immediate 'drop table sandbox.agrmnt_target';
exception
	when others then null;
end;

create table sandbox.agrmnt_target (agrmnt varchar2(100),
									start_year number,
									period date,
									agrmnt_sum number,
									type_operation char(1),
									load_date timestamp)
partition by range (load_date)
(partition agrmnt_target_prt_1 values less than (maxvalue))

-- Заполняем целевую таблицу исходными данными
insert into sandbox.agrmnt_target
select	agrmnt, start_year, period, agrmnt_sum, type_operation, cast(sysdate as timestamp) as load_date
from sandbox.agrmnt a;

-- Создаем временную партиционированную таблицу в которую будем писать новые данные и с которой будем обмениваться партицией
begin
	execute immediate 'drop table sandbox.agrmnt_target_tmp';
exception
	when others then null;
end;

create table sandbox.agrmnt_target_tmp for exchange with table sandbox.agrmnt_target;

-- Заполняем временную таблицу измененными данными из sandbox.agrmnt_source
insert into sandbox.agrmnt_target_tmp
select 	agrmnt, start_year, period, agrmnt_sum, type_operation, cast(sysdate as timestamp) as load_date
from sandbox.agrmnt_source a

-- Делаем замену партиций
alter table sandbox.agrmnt_target exchange partition agrmnt_target_prt_1 with table sandbox.agrmnt_target_tmp without validation;
  
/*
 * Пример реализации scd2 с историчностью
 * 
 * таблица agrmnt_target - целевая таблица
 * таблица agrmnt_source - таблица с новыми данными
 * 
 * Требования к алгоритму
 * 1. Если запись была обновлена необходимо закрыть старую запись и добавить новую
 * 2. Если запись была удалена необходимо закрыть старую запись
 * 3. Если запись новая ее небходимо вставить 
 * 
 * Перед выполнением выполнить блок "Подготовка данных"
 */

-- Создаем целевую таблицу
begin
	execute immediate 'drop table sandbox.agrmnt_target';
exception
	when others then null;
end;

create table sandbox.agrmnt_target (agrmnt varchar2(100),
									start_year number,
									period date,
									agrmnt_sum number,
									type_operation char(1),
									hash_diff raw(32),
									load_date timestamp,
									close_date timestamp);

-- Заполняем целевую таблицу исходными данными
insert into sandbox.agrmnt_target
select	agrmnt,
		start_year,
		period,
		agrmnt_sum,
		type_operation,
		standard_hash(agrmnt||'/'||start_year||'/'||period||'/'||agrmnt_sum||'/'||type_operation, 'SHA256') as hash_diff,
		cast(sysdate as timestamp) as load_date, 
		cast(null as timestamp) as close_date
from sandbox.agrmnt a;

-- Обновляем целевую таблицу данными из sandbox.agrmnt_source
merge into sandbox.agrmnt_target a
using (	with tmp_source as (select 	agrmnt, start_year, period, agrmnt_sum, type_operation,
									standard_hash(agrmnt||'/'||start_year||'/'||period||'/'||agrmnt_sum||'/'||type_operation, 'SHA256') as hash_diff
							from sandbox.agrmnt_source)
		select ts.*, ta.hash_diff as hash_diff_ta
		from tmp_source ts
		full join (select * from sandbox.agrmnt_target where close_date is null) ta on (ta.hash_diff = ts.hash_diff)
		where ta.hash_diff is null or ts.hash_diff is null) b
on (a.hash_diff = b.hash_diff_ta)
when matched then 
	update set close_date = sysdate where close_date is null
when not matched then
	insert (agrmnt, start_year, period, agrmnt_sum, type_operation, hash_diff, load_date)
	values (b.agrmnt, b.start_year, b.period, b.agrmnt_sum, b.type_operation, b.hash_diff, sysdate)
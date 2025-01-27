/**************************
* Автор: Andrey Shurenkov
* Код для Oracle
*
* Алгоритм FIFO на данных таблицы agrmnt. Для создание табилцы agrmnt и заполнение ее тестовыми данными
* необходимо выполнить скрипт dataset.sql.
***************************/

/*
Пример исходного массива

|AGRMNT           |START_YEAR|PERIOD                 |AGRMNT_SUM|TYPE_OPERATION|LOAD_DATE              |TYPE_DML|
|-----------------|----------|-----------------------|----------|--------------|-----------------------|--------|
|001/010/RKTKIODXT|2 023     |2024-01-01 00:00:00.000|1 208     |A             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-02-01 00:00:00.000|1 208     |A             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-03-01 00:00:00.000|1 208     |A             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-01-26 08:22:27.000|1 191     |P             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-02-16 09:11:57.000|1 166     |P             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-03-23 14:39:16.000|1 196     |P             |2024-06-21 14:19:24.000|I       |

Результат работы алгоритма

|AGRMNT           |START_YEAR|PERIOD_ACR             |AGRMNT_SUM_ACR|PERIOD_PR              |AGRMNT_SUM_PR|LOAD_DATE              |TYPE_DML|
|-----------------|----------|-----------------------|--------------|-----------------------|-------------|-----------------------|--------|
|001/010/RKTKIODXT|2 023     |2024-01-01 00:00:00.000|1 191         |2024-01-26 08:22:27.000|1 191        |2024-06-21 14:24:05.000|I       |
|001/010/RKTKIODXT|2 023     |2024-01-01 00:00:00.000|17            |2024-02-16 09:11:57.000|17           |2024-06-21 14:24:05.000|I       |
|001/010/RKTKIODXT|2 023     |2024-02-01 00:00:00.000|1 149         |2024-02-16 09:11:57.000|1 149        |2024-06-21 14:24:05.000|I       |
|001/010/RKTKIODXT|2 023     |2024-02-01 00:00:00.000|59            |2024-03-23 14:39:16.000|59           |2024-06-21 14:24:05.000|I       |
|001/010/RKTKIODXT|2 023     |2024-03-01 00:00:00.000|1 137         |2024-03-23 14:39:16.000|1 137        |2024-06-21 14:24:05.000|I       |
|001/010/RKTKIODXT|2 023     |2024-03-01 00:00:00.000|71            |                       |             |2024-06-21 14:24:05.000|I       |
*/

begin
	execute immediate 'drop table sandbox.agrmnt_fifo';
exception
	when others then null;
end;

-- алгортим, специально разбит по шагам что бы можно было посмотреть результат каждого действия
create table sandbox.agrmnt_fifo as
with	tmp_accrual as (select	fe.*,
								sum(fe.agrmnt_sum) over (partition by agrmnt order by period) agrmnt_sum_sum
					   	from agrmnt fe
					  	where type_operation = 'A'),
		tmp_payment as (select	fe.*,
								sum(fe.agrmnt_sum) over (partition by agrmnt order by period) agrmnt_sum_sum
						from agrmnt fe
						where type_operation = 'P'),
		tmp_step_1 as (	select	nvl(ta.agrmnt,tp.agrmnt) agrmnt,
								nvl(ta.start_year,tp.start_year) start_year,
							    ta.period period_acr,
							    ta.agrmnt_sum agrmnt_sum_acr,
							    tp.period period_pr,
							    tp.agrmnt_sum agrmnt_sum_pr,
							    ta.agrmnt_sum_sum agrmnt_sum_sum_acr,
							    tp.agrmnt_sum_sum agrmnt_sum_sum_pr
					   	from tmp_accrual ta
						full join tmp_payment tp on (	ta.agrmnt = tp.agrmnt and
														ta.agrmnt_sum_sum = tp.agrmnt_sum_sum)
					  	order by nvl(ta.agrmnt,tp.agrmnt), nvl(ta.agrmnt_sum_sum,tp.agrmnt_sum_sum)), -- сортировка для наглядности результата данного действия	
		tmp_step_2 as (	select 	ts1.agrmnt,
		  						ts1.start_year,
						 	    first_value(period_acr) ignore nulls over (partition by agrmnt order by nvl(ts1.agrmnt_sum_sum_acr,ts1.agrmnt_sum_sum_pr) rows  between current row and unbounded following) period_acr,
							    first_value(agrmnt_sum_acr) ignore nulls over (partition by agrmnt order by nvl(ts1.agrmnt_sum_sum_acr,ts1.agrmnt_sum_sum_pr) rows between current row and unbounded following) agrmnt_sum_acr,
							    first_value(period_pr) ignore nulls over (partition by agrmnt order by nvl(ts1.agrmnt_sum_sum_acr,ts1.agrmnt_sum_sum_pr) rows between current row and unbounded following) period_pr,
							    first_value(agrmnt_sum_pr) ignore nulls over (partition by agrmnt order by nvl(ts1.agrmnt_sum_sum_acr,ts1.agrmnt_sum_sum_pr) rows between current row and unbounded following) agrmnt_sum_pr,
							    nvl(agrmnt_sum_sum_acr,agrmnt_sum_sum_pr) agrmnt_sum_sum
						from tmp_step_1 ts1),
		tmp_step_3 as (	select 	ts2.agrmnt,
		  						ts2.start_year,
						 	    ts2.period_acr,
							    ts2.agrmnt_sum_acr,
							    ts2.period_pr,
							    ts2.agrmnt_sum_pr,
							    ts2.agrmnt_sum_sum - nvl(lag(ts2.agrmnt_sum_sum) over (partition by ts2.agrmnt order by agrmnt_sum_sum),0) agrmnt_sum_new
						from tmp_step_2 ts2),
		tmp_step_4 as (	select 	ts3.agrmnt,
	      						ts3.start_year,
						  	    ts3.period_acr,
							    case when ts3.agrmnt_sum_acr is not null then ts3.agrmnt_sum_new end agrmnt_sum_acr,
							    ts3.period_pr,
							    case when ts3.agrmnt_sum_pr is not null then ts3.agrmnt_sum_new end agrmnt_sum_pr,
							    cast(sysdate as timestamp) load_date,
							    'i' type_dml
						from tmp_step_3 ts3)
select * 
from tmp_step_4;

-- Проверяем, если ничего не возращает значит все корректно
with	tmp_data_res as (	select agrmnt, sum(agrmnt_sum_acr) agrmnt_sum_acr, sum(agrmnt_sum_pr) agrmnt_sum_pr
					 	  	from agrmnt_fifo
					 	 	group by agrmnt),
		tmp_data_ex as (select *
   	   					from (select agrmnt, agrmnt_sum, type_operation from agrmnt)
						pivot (sum(agrmnt_sum) for type_operation in ('A' as agrmnt_sum_acr, 'P' as agrmnt_sum_pr)))
select res.*, ex.* 
from tmp_data_res res
join tmp_data_ex ex on (res.agrmnt = ex.agrmnt)
where 	res.agrmnt_sum_acr != ex.agrmnt_sum_acr or 
		res.agrmnt_sum_pr != ex.agrmnt_sum_pr;
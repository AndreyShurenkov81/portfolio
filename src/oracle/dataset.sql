/**************************
* Автор: Andrey Shurenkov
* Код Oracle
*
* Код создает договора у которых есть плановая и фактическая дата платежей а также плановая и фактическая сумма платежей.
* Для type_operation = A (плановый платеж) period - дата когда должен быть платеж, agrmnt_sum - сумма которую необходимо заплатить
* Для type_operation = P (фактический платеж) period - дата когда был произведен платеж, agrmnt_sum - сумма которую заплатили
* Количество договоров регулируется параметром vCountAgrmnt
* Количество плановых/фактических платежей для договора равно количеству месяцев и регулируется параметром vCountPeriod.
* При значениях vCountAgrmnt = 1, vCountPeriod = 12 будет сформировано 24 записи, 12 операций с типом А и 12 операций с типом P
***************************/

/*
Пример генерируемого массива 

|AGRMNT           |START_YEAR|PERIOD                 |AGRMNT_SUM|TYPE_OPERATION|LOAD_DATE              |TYPE_DML|
|-----------------|----------|-----------------------|----------|--------------|-----------------------|--------|
|001/010/RKTKIODXT|2 023     |2024-01-01 00:00:00.000|1 208     |A             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-02-01 00:00:00.000|1 208     |A             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-03-01 00:00:00.000|1 208     |A             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-01-26 08:22:27.000|1 191     |P             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-02-16 09:11:57.000|1 166     |P             |2024-06-21 14:19:24.000|I       |
|001/010/RKTKIODXT|2 023     |2024-03-23 14:39:16.000|1 196     |P             |2024-06-21 14:19:24.000|I       |
*/

begin
	execute immediate 'drop table sandbox.agrmnt';
exception
	when others then null;
end;

create table sandbox.agrmnt (	agrmnt varchar2(100),
								start_year number,
							 	period date,
						 	 	agrmnt_sum number,
						 	 	type_operation char(1),
						 	 	load_date date default sysdate,
						 	 	type_dml char(1) default 'i');
	  
-- Генерируем данные
declare
	vcount number := 1; -- количество циклов
	vcountagrmnt number := 1; -- количество договоров в цикле
	vcountperiod number := 12; -- количество платежей в договоре (1 месяц = 1 платеж) 
begin
	--execute immediate 'truncate table sandbox.agrmnt';	
	for i in 1 .. vcount
	loop
	 	insert /*+ append */ into sandbox.agrmnt (agrmnt, start_year, period, agrmnt_sum, type_operation)
		with 	tmp_agrmnt as (	select	/*+ materialize */ 
										'001/'||trim(to_char(round(dbms_random.value(1,20)),'000'))||'/'||dbms_random.string('u',9) agrmnt, 
										round(dbms_random.value(2020,2024)) start_year, 
										round(dbms_random.value(1000,2000)) agrmnt_sum, 
										'A' type_operation
								from dual connect by level <= vcountagrmnt),
				tmp_agrmnt_a as (	select ta.*, tp.*
		   				   		 	from tmp_agrmnt ta
									cross join (select add_months(trunc(sysdate,'yyyy'),level-1) period from dual connect by level <= vcountperiod) tp)
		select agrmnt, start_year, period, agrmnt_sum, type_operation
		from tmp_agrmnt_a
		union all
		select agrmnt, start_year, period+dbms_random.value(1,to_number(to_char(last_day(period),'dd'))) period, round(dbms_random.value(agrmnt_sum-100,agrmnt_sum+100)) agrmnt_sum, 'P' type_operation  
		from tmp_agrmnt_a;
		commit;
	end loop;
end;

create index idx_agrmnt_01 on sandbox.agrmnt (agrmnt);
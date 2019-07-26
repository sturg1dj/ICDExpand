/************************************************
* Code expander: Inspired by Austin Davis
* Author: Dan Sturgeon
* When given a list of ICD codes this macro takes
* those codes and expands them (if they need to 
* be expanded). 
*
*
*
*
* NOTE: Only factors in current codes AND codes
* that have been used in Medicare data!
************************************************/


%MACRO ICDExpand(DATA=,
				 CODE =,
				 TYPE =,
				 VER=9,
				 FLAG =);
*OPTIONS MLOGIC;
/*Location of ICD9 data*/
libname ICD "F:\Code Library\SAS\ICD_expander";

/*For testing*/
/*%LET DATA=TEST_DATA;*/
/*%LET CODE = dxcode;*/
/*%LET TYPE = DX;*/
/*%LET FLAG = flagname;*/

DATA DONE CODE;
SET &DATA;
	CODE = compress(upcase(&CODE));

	IF FIND(CODE,'-') GE 1 THEN DO;
		TYPE = 1;
		MIN = SCAN(CODE,1,'-');
		MAX = SCAN(CODE,2,'-');
		OUTPUT CODE;
	END;

	ELSE IF FIND(CODE,'*') GE 1 THEN DO;
		TYPE = 2;
		MIN = SCAN(CODE,1,'*');
		MAX = SCAN(CODE,1,'*');
		OUTPUT CODE;
	END;

	ELSE DO;
		TYPE = 0;
		OUTPUT DONE;
	END;
RUN;

	%IF &ver = 10 %THEN %DO;
		%IF %UPCASE("&TYPE") = "DX" %THEN %DO;
			%LET JOIN = ICD.ICD10dx;
		%END;

		%IF %UPCASE("&TYPE") = "PROC" %THEN %DO;
			%LET JOIN = ICD.ICD10pr;
		%END;

	%END;

	%ELSE %IF &ver = 9 %THEN %DO;

		%IF %UPCASE("&TYPE") = "DX" %THEN %DO;
			%LET JOIN = ICD.ICD9DXGROUP;
		%END;

		%IF %UPCASE("&TYPE") = "PROC" %THEN %DO;
			%LET JOIN = ICD.ICD9PROCGROUP;
		%END;
	%END;
	 

PROC SQL;
CREATE TABLE EXPAND1 AS
SELECT B.CODE,
       B.DESCRIPTION,
	   A.&Flag
  FROM CODE A,
       &JOIN B
 WHERE UPCASE(B.CODE) BETWEEN A.MIN AND A.MAX;
QUIT;

/********************************************
* Get list of Max Variables to expand out
********************************************/
PROC SQL noprint;
SELECT MAX
  INTO :LIST SEPARATED BY ' '
  FROM CODE;
QUIT;


%DO I = 1 %TO &SQLOBS;
	%LET VAR = %SCAN(&LIST.,&I.,' ');

	PROC SQL;
	CREATE TABLE EXPAND2 AS
	SELECT 	DISTINCT 
			B.CODE,
       		B.DESCRIPTION,
	   		A.&FLAG
  	 FROM 	CODE A,
       		&JOIN B
    WHERE 	UPCASE(B.CODE) LIKE "&VAR%"
      AND   UPCASE(A.MAX) = "&VAR";
	QUIT;

	DATA EXPAND1;
	SET EXPAND1 EXPAND2;
	RUN;
%END;

	/*Join Descriptions and flags to the rest*/

		PROC SQL;
	CREATE TABLE EXPAND3 AS
	SELECT 	DISTINCT 
			A.CODE,
       		CASE
				WHEN B.DESCRIPTION IS NULL THEN 'NOT FOUND'
				ELSE B.DESCRIPTION END AS DESCRIPTION,
	   		A.&FLAG
  	 FROM 	DONE A 
     LEFT OUTER JOIN &JOIN B ON UPCASE(A.CODE) = UPCASE(B.CODE);
	QUIT;


PROC SQL;
CREATE TABLE FINAL_CODES AS
SELECT DISTINCT *
  FROM (SELECT DISTINCT *
          FROM EXPAND1

		  UNION ALL

		SELECT DISTINCT *
		  FROM EXPAND3
		);
QUIT;

PROC SQL;
DROP TABLE EXPAND1;
DROP TABLE EXPAND2;
DROP TABLE EXPAND3;
DROP TABLE DONE;
QUIT;

%MEND;


/*DATA test;*/
/*LENGTH CODE $10.;*/
/*INPUT CODE $ FLAG $;*/
/*DATALINES;*/
/*800* A*/
/*9501-9503 B*/
/*95901 C*/
/*;*/
/*RUN;*/
/**/
/*%ICDExpand(DATA=test,CODE=code,TYPE=DX,FLAG=FLAG);*/

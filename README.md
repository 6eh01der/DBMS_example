Example of access MSSQL and PostgreSQL data from Powershell. Specific of this example is that the data collects via simple ```select * from``` but all subsequent manipulations are made by Powershell. At the end script will generate csv with rows count of specific tables.

Required components:

SMO - https://learn.microsoft.com/ru-ru/sql/relational-databases/server-management-objects-smo/overview-smo?view=sql-server-ver16

psqlODBC - https://odbc.postgresql.org/

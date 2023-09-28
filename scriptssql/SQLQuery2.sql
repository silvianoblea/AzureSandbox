	USE AzureDevOps_Configuration;
	CREATE USER [Server-vm01] FROM EXTERNAL PROVIDER
	ALTER ROLE [db_owner] ADD MEMBER [Server-vm01]
	ALTER USER [Server-vm01] WITH DEFAULT_SCHEMA=dbo
GO
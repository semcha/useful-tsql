-- Drop session if exists
IF (SELECT [name] FROM sys.dm_xe_sessions WHERE [name] = N'QueryMetrics') IS NOT NULL
	DROP EVENT SESSION [Queries] ON SERVER;
GO

-- Create session
CREATE EVENT SESSION [QueryMetrics] ON SERVER 
ADD EVENT sqlserver.existing_connection(
    ACTION(sqlserver.query_hash,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.client_app_name,sqlserver.database_name,sqlserver.nt_username,sqlserver.username,sqlserver.server_principal_name)),
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.query_hash,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.client_app_name,sqlserver.database_name,sqlserver.nt_username,sqlserver.username,sqlserver.server_principal_name)
    WHERE ([duration]>=(120000000) AND ([sqlserver].[is_system]=(0)))),
ADD EVENT sqlserver.sp_statement_completed(SET collect_object_name=(1)
    ACTION(sqlserver.query_hash,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.client_app_name,sqlserver.database_name,sqlserver.nt_username,sqlserver.username,sqlserver.server_principal_name)
    WHERE ([duration]>=(120000000) AND ([sqlserver].[is_system]=(0)))),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.query_hash,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.client_app_name,sqlserver.database_name,sqlserver.nt_username,sqlserver.username,sqlserver.server_principal_name)
    WHERE ([duration]>=(120000000) AND ([sqlserver].[is_system]=(0)))),
ADD EVENT sqlserver.sql_statement_completed(SET collect_statement=(1)
    ACTION(sqlserver.query_hash,sqlserver.sql_text,sqlserver.client_hostname,sqlserver.client_app_name,sqlserver.database_name,sqlserver.nt_username,sqlserver.username,sqlserver.server_principal_name)
    WHERE ([duration]>=(120000000) AND ([sqlserver].[is_system]=(0))))
ADD TARGET package0.event_file(SET filename=N'E:\ExtendedEvents\QueryMetrics.xel',max_file_size=(128),max_rollover_files=(20))
GO

-- Start the event session
ALTER EVENT SESSION [QueryMetrics] ON SERVER STATE = START;
GO

-- Check session 
SELECT * FROM sys.dm_xe_sessions;
GO

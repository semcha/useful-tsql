SELECT
	database_id
   ,[name]
   ,recovery_model_desc
   ,[compatibility_level]
   ,is_read_committed_snapshot_on
   ,is_parameterization_forced
   ,delayed_durability_desc
FROM sys.databases;


SELECT
	*
FROM sys.configurations
ORDER BY [name];
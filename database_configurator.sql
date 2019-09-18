USE master;
GO

-- https://www.sqlskills.com/blogs/erin/query-store-settings/
SELECT
	q.database_settings_sql
FROM
	sys.databases AS db
	CROSS APPLY (
		SELECT
			REPLACE(N'
				USE [@DATABASE_NAME];
				GO
				ALTER AUTHORIZATION ON DATABASE::[@DATABASE_NAME] TO [sa];
				GO
				ALTER DATABASE [@DATABASE_NAME] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
				GO
				ALTER DATABASE [@DATABASE_NAME] SET PARAMETERIZATION FORCED WITH ROLLBACK IMMEDIATE;
				GO
				ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SNIFFING = OFF;
				GO
				ALTER DATABASE [@DATABASE_NAME] SET QUERY_STORE (
					OPERATION_MODE = READ_WRITE,
					CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 90),
					DATA_FLUSH_INTERVAL_SECONDS = 900,
					MAX_STORAGE_SIZE_MB = 4096,
					INTERVAL_LENGTH_MINUTES = 60,
					SIZE_BASED_CLEANUP_MODE = AUTO,
					QUERY_CAPTURE_MODE = AUTO,
					MAX_PLANS_PER_QUERY = 200,
					WAIT_STATS_CAPTURE_MODE = ON
				);
				GO
				ALTER DATABASE [@DATABASE_NAME] SET QUERY_STORE = ON;
				GO'
			, N'@DATABASE_NAME'
			, db.[name]) AS database_settings_sql
	) AS q
WHERE
	db.database_id > 4;

DECLARE @CompatibilityLevel nvarchar(10) = (
	SELECT
		CAST(CAST(SERVERPROPERTY ('ProductMajorVersion') AS nvarchar(10)) * 10 AS nvarchar(10))
);

SELECT
    db.[name] as [database_name],
    q.database_settings_sql
FROM
    sys.databases AS db
    CROSS APPLY (
        SELECT
            REPLACE(REPLACE(N'
				USE [@DATABASE_NAME];
				GO
				ALTER DATABASE [@DATABASE_NAME] SET RECOVERY SIMPLE;
				GO
				ALTER DATABASE [@DATABASE_NAME] SET COMPATIBILITY_LEVEL = @COMPATIBILITY_LEVEL;
				GO'
            , N'@DATABASE_NAME', db.[name])
			, N'@COMPATIBILITY_LEVEL', @CompatibilityLevel) AS database_settings_sql
    ) AS q
WHERE
    db.database_id > 4;
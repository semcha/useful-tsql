DECLARE @login_name nvarchar(255) = N'';

IF OBJECT_ID(N'tempdb..##drop_logouser_042') IS NOT NULL
    DROP TABLE ##drop_logouser_042;
CREATE TABLE ##drop_logouser_042 (
    [name] nvarchar(255)
   ,[sid] varbinary(85)
   ,[drop_sql] nvarchar(4000)
);

INSERT INTO ##drop_logouser_042 (
    [name]
   ,[sid]
   ,drop_sql
)
SELECT
    sp.[name]
   ,sp.[sid]
   ,N'DROP LOGIN [' + sp.[name] + N'];' AS drop_sql
FROM
    sys.server_principals AS sp
WHERE
    sp.[type] IN (N'S', N'U') -- SQL Login, Windows Login
    AND sp.[name] = @login_name
ORDER BY sp.[name];

DECLARE @SQL nvarchar(max) = N'
    USE ?
    INSERT INTO ##drop_logouser_042 (
        usr.[name]
       ,usr.[sid]
       ,usr.drop_sql
    )
    SELECT
        usr.[name]
        ,usr.[sid]
        ,N''USE ['' + DB_NAME() + N'']; DROP USER ['' + usr.[name] + N''];'' AS drop_sql
    FROM
        sys.sysusers AS usr
    WHERE
        usr.sid IN (SELECT sid FROM ##drop_logouser_042);';

EXECUTE sp_MSforeachdb @SQL;

SELECT
    *
FROM
    ##drop_logouser_042;

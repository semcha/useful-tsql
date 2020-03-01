
EXECUTE msdb.dbo.sp_Blitz;

-- @Mode = 3 - Missing Index Detail
EXECUTE msdb.dbo.sp_BlitzIndex @GetAllDatabases = 1, @Mode = 3;

-- @Mode = 4 - Diagnose Details
EXECUTE msdb.dbo.sp_BlitzIndex @GetAllDatabases = 1, @Mode = 4;

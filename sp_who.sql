-- Require SQL Server First Responder Kit installed in msdb database
-- http://FirstResponderKit.org
-- Require sp_whoisactive installed in msdb database
-- https://github.com/amachanic/sp_whoisactive

-- Show active sessions
EXEC msdb.dbo.sp_BlitzWho;

-- Show detailed information
EXEC msdb.dbo.sp_BlitzWho @ExpertMode = 1;

-- Show sleepings SPIDs
EXEC msdb.dbo.sp_BlitzWho @ShowSleepingSPIDs = 1;

-- Show all sessions (sp_WhoIsActive)
EXEC msdb.dbo.sp_WhoIsActive @show_sleeping_spids = 2;

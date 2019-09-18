-- Require SQL Server First Responder Kit installed in msdb database
-- http://FirstResponderKit.org
-- Require sp_whoisactive installed in msdb database
-- https://github.com/amachanic/sp_whoisactive

USE msdb;
GO

-- Show active sessions
EXEC dbo.sp_BlitzWho;

-- Show detailed information
EXEC dbo.sp_BlitzWho @ExpertMode = 1;

-- Show sleepings SPIDs
EXEC dbo.sp_BlitzWho @ShowSleepingSPIDs = 1;

-- Show all sessions (sp_WhoIsActive)
EXEC dbo.sp_WhoIsActive @show_sleeping_spids = 2;

USE [master];
GO

-- https://blog.pythian.com/sql-server-default-configurations-change/

-- Enable Advanced options
EXEC sys.sp_configure N'show advanced options', 1;
RECONFIGURE;
EXEC sys.sp_configure N'xp_cmdshell', 1;
RECONFIGURE;
GO

-- https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
-- https://bornsql.ca/s/memory/
DECLARE @max_server_memory_mb int = (
	SELECT
		CAST(
		qry.memory_mb
		- 1024
		- (1024 * IIF(qry.memory_mb >= 16384, 16384, qry.memory_mb) / 4096.)
		- (1024 * IIF(qry.memory_mb <= 16384, 0, qry.memory_mb - 16384) / 8192.)
		AS int) / 1024 * 1024
	FROM
		(
			SELECT
				(total_physical_memory_kb / 1024.) AS memory_mb
			FROM
				sys.dm_os_sys_memory
		) AS qry
);

-- https://support.microsoft.com/en-gb/help/2806535/
DECLARE @cpu_maxdop int = (
	SELECT
		IIF(cpu_count < 8, cpu_count, 8) AS cpu_maxdop
	FROM
		sys.dm_os_sys_info
);

-- Ad Hoc Settings
EXEC sys.sp_configure N'optimize for ad hoc workloads', 1
EXEC sys.sp_configure N'Ad Hoc Distributed Queries', 1;

-- Remote DAC
EXEC sys.sp_configure N'remote admin connections', 1;

-- Backups settings
EXEC sys.sp_configure N'backup compression default', 1;
EXEC sys.sp_configure N'backup checksum default', 1;

-- Fill Factor
EXEC sys.sp_configure N'fill factor (%)', 90;

-- Parallelism
EXEC sys.sp_configure N'cost threshold for parallelism', 50;
EXEC sys.sp_configure N'max degree of parallelism', @cpu_maxdop;

-- High Performance Power Option
-- http://desertdba.com/find-and-fix-that-troublesome-windows-power-setting/
EXEC sys.xp_cmdshell N'powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';

-- Max Server Memory
EXEC sys.sp_configure N'max server memory (MB)', @max_server_memory_mb;

GO
-- Disable Advanced options
EXEC sys.sp_configure N'xp_cmdshell', 0;
EXEC sys.sp_configure N'show advanced options', 0;
GO
RECONFIGURE WITH OVERRIDE
GO

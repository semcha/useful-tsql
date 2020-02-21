select
	jb.[name] AS job_name
	,jb.owner_sid
	,lgn.[name] as [login_name]
	,REPLACE(
		N'EXEC msdb.dbo.sp_update_job @job_id=N''${JOB_ID}'', @owner_login_name=N''sa'''
		,N'${JOB_ID}'
		,jb.job_id
	) AS [sql]
from
	msdb.dbo.sysjobs as jb
	inner join [master].dbo.syslogins as lgn
		ON jb.owner_sid = lgn.[sid]
where
	jb.owner_sid != 0x01 -- sa
	and lgn.[name] != N'NT SERVICE\ReportServer'
order by jb.[name];
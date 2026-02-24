program crawl;

uses
{$ifdef unix}
	cthreads,
{$endif}
	openssl,
	sysutils,
	dos,
	AxeProject,
	AxeUser,
	AxeDatabase;

var
	I : Integer;
begin
	I := 1;

	InitSSLInterface();

{$ifdef DATABASE}
	AxeDatabaseConnect(GetEnv('TOOLBOX_SOLR_HOSTNAME'), GetEnv('TOOLBOX_SOLR_PORT'));
{$endif}

	while I < ParamCount do
	begin
		if ParamStr(I) = '--user' then
		begin
			I := I + 1;
			AxeUserGet(ParamStr(I));
		end
		else if ParamStr(I) = '--directory' then
		begin
			I := I + 1;
			CreateDir(ParamStr(I));
			ChDir(ParamStr(I));
		end
		else
		begin
			AxeProjectGet(ParamStr(I));
		end;

		I := I + 1;
	end;
end.

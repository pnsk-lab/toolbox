program crawl;

uses
{$ifdef unix}
	cthreads,
	baseunix,
{$endif}
	openssl,
	sysutils,
	dos,
	AxeProject,
	AxeUser,
	AxeDatabase,
	AxeUtility;

{$ifdef unix}
procedure SafeShutdown(Sig : cint); cdecl;
begin
	AxeUtilityShutdown := true;
end;
{$endif}

var
	I : Integer;
begin
	I := 1;

	InitSSLInterface();

{$ifdef unix}
	FpSignal(SIGINT, @SafeShutdown);
	FpSignal(SIGTERM, @SafeShutdown);
{$endif}
{$ifdef DATABASE}
	AxeDatabaseConnect(GetEnv('TOOLBOX_SOLR_HOSTNAME'), GetEnv('TOOLBOX_SOLR_PORT'));
{$endif}

	AxeUtilityShutdown := false;

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
		if AxeUtilityShutdown then break;

		I := I + 1;
	end;
end.

program crawlserver;

uses
	{$ifdef unix}
	cthreads,
	baseunix,
	{$endif}
	fphttpapp,
	httproute,
	sysutils,
	dos,
	CrawlServerRoot,
	CrawlServerData,
	CrawlServerStatic;

var
	I : Integer;

begin
	I := 1;

	{$ifdef unix}
	FpSignal(SIGPIPE, SignalHandler(SIG_IGN));
	{$endif}

	while I < ParamCount do
	begin
		if ParamStr(I) = '--directory' then
		begin
			I := I + 1;
			ChDir(ParamStr(I));
		end;

		I := I + 1;
	end;

	HTTPRouter.RegisterRoute('/', @CrawlServerRootRoute);
	HTTPRouter.RegisterRoute('/data/assets/:file', @CrawlServerDataAssetsRoute);
	HTTPRouter.RegisterRoute('/data/projects/:id/:timestamp/:file', @CrawlServerDataProjectsRoute);
	HTTPRouter.RegisterRoute('/static/:file', @CrawlServerStaticRoute);

	Application.Port := StrToInt(GetEnv('CRAWL_PORT'));
	Application.Threaded := true;

	WriteLn('Server ready');

	Application.Initialize();
	Application.Run();
end.

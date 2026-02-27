program crawlserver;

uses
	{$ifdef unix}
	cthreads,
	baseunix,
	{$endif}
	fphttpapp,
	httproute,
	httpdefs,
	sysutils,
	dos,
	eventlog,
	HammerRoot,
	HammerData,
	HammerStatic,
	HammerInfo,
	HammerDatabase;

procedure OnShowRequestException(Res : TResponse; AnException : Exception; var handled : Boolean);
begin
	Res.ContentType := 'text/html';
	if (AnException.ClassName = 'EFOpenError') or (AnException.ClassName = 'EInOutError') then
	begin
		Res.Code := 404;
		Res.CodeText := 'Not Found';
	end
	else
	begin
		Res.Code := 500;
		Res.CodeText := 'Internal Server Error';
	end;
	Res.Content := '<html><head><title>' + AnException.ClassName + '</title></head><body><h1>' + AnException.ClassName + '</h1>' + AnException.Message + '<hr><i>Hammer HTTP Server</i></body></html>';

	handled := true;
end;

var
	I : Integer;

begin
	I := 1;

	{$ifdef unix}
	FpSignal(SIGPIPE, SignalHandler(SIG_IGN));
	{$endif}

	Randomize();

	HammerInfoDirectory := '';
	HammerDatabaseConnect(GetEnv('TOOLBOX_SOLR_HOSTNAME'), GetEnv('TOOLBOX_SOLR_PORT'));
	while I <= ParamCount do
	begin
		if ParamStr(I) = '--directory' then
		begin
			I := I + 1;
			HammerInfoDirectory := ParamStr(I);
		end;

		I := I + 1;
	end;

	HTTPRouter.RegisterRoute('/', @HammerRootRoute, true);
	HTTPRouter.RegisterRoute('/data/assets/:file', @HammerDataAssetsRoute);
	HTTPRouter.RegisterRoute('/data/projects/:id/:timestamp/:file', @HammerDataProjectsRoute);
	HTTPRouter.RegisterRoute('/data/users/:user/:file', @HammerDataUsersRoute);
	HTTPRouter.RegisterRoute('/static/:file', @HammerStaticRoute);

	Application.Port := StrToInt(GetEnv('TOOLBOX_HAMMER_PORT'));
	Application.Threaded := true;
	Application.OnShowRequestException := @OnShowRequestException;

	WriteLn('Server ready');

	Application.Initialize();
	Application.Run();
end.

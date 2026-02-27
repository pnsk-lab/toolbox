unit AxeUser;

interface
procedure AxeUserGet(UserName : String);

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	sysutils,
	classes,
	AxeProject,
	AxeUtility;

type
	TThreadParams = record
		ID : String;
	end;
	PThreadParams = ^TThreadParams;
	TProjectThread = class(TThread)
	public
		Params : PThreadParams;
	protected
		procedure Execute(); override;
	end;

const
	MaxLimits : Integer = 20;
	MaxThreads : Integer = 32;

var
	ThreadFinished : Integer;

procedure TProjectThread.Execute();
begin
	AxeProjectGet(Params^.ID);

	Dispose(Params);

	InterLockedIncrement(ThreadFinished);
end;

procedure AxeUserGet(UserName : String);
var
	JStr : String;
	JData, JImage, JItem, JID : TJSONData;
	N : Integer;
	I : Integer;
	Param : PThreadParams;
	Params : Array of PThreadParams;
	Thread : TProjectThread;
	TF : TextFile;
	FS : TFileStream;
	Path : String;
	Client : TFPHTTPClient;
begin
	N := 0;

	SetLength(Params, 0);

	WriteLn(StdErr, '[' + UserName + '] Getting metadata');
	while true do
	begin
		try JStr := TFPHTTPClient.SimpleGet('https://api.scratch.mit.edu/users/' + UserName);
		except
			on E : EHTTPClient do
			begin
				exit;
			end;
			on E : Exception do
			begin
				continue;
			end;
		end;
		break;
	end;
	
	CreateDir('users');
	CreateDir('users/' + UserName);

	AssignFile(TF, 'users/' + UserName + '/info.json');
	Rewrite(TF);
	Write(TF, JStr);
	CloseFile(TF);

	JData := GetJSON(JStr, false);

	JImage := JData.FindPath('profile.images.90x90');
	if Assigned(JImage) then
	begin
		WriteLn(StdErr, '[' + UserName + '] Getting icon');
		Path := 'users/' + UserName + '/icon.' + AxeUtilityGetExtension(JImage.AsString);
		while true do
		begin
			FS := TFileStream.Create(Path, fmCreate or fmOpenWrite);
			Client := TFPHTTPClient.Create(nil);
			Client.AllowRedirect := true;
			try Client.Get(JImage.AsString, FS);
			except
				on E : EHTTPClient do
				begin
					FS.Free();
					Client.Free();
					DeleteFile(Path);
					exit;
				end;
				on E : Exception do
				begin
					FS.Free();
					Client.Free();
					DeleteFile(Path);
					continue;
				end;
			end;
			FS.Free();
			Client.Free();
			break;
		end;
	end;
		
	JData.Free();

	WriteLn(StdErr, '[' + UserName + '] Populating...');
	while true do
	begin
		while true do
		begin
			try JStr := TFPHTTPClient.SimpleGet('https://api.scratch.mit.edu/users/' + UserName + '/projects?limits=' + IntToStr(MaxLimits) + '&offset=' + IntToStr(N));
			except
				on E : EHTTPClient do
				begin
					exit;
				end;
				on E : Exception do
				begin
					continue;
				end;
			end;
			break;
		end;
		JData := GetJSON(JStr, false);

		if JData.Count = 0 then
		begin
			JData.Free();
			break;
		end;

		for I := 0 to JData.Count - 1 do
		begin
			JItem := JData.Items[I];
			JID := JItem.FindPath('id');

			if Assigned(JID) then
			begin
				New(Param);
				Param^.ID := JID.AsString;

				Insert(Param, Params, Length(Params));
			end;
		end;

		JData.Free();

		N := N + MaxLimits;
	end;
	
	ThreadFinished := MaxThreads;
	for I := 0 to Length(Params) - 1 do
	begin
		InterLockedDecrement(ThreadFinished);

		Thread := TProjectThread.Create(true);
		Thread.FreeOnTerminate := true;
		Thread.Params := Params[I];
		Thread.Start();

		while not(AxeUtilityShutdown) and (ThreadFinished = 0) do;
		if AxeUtilityShutdown then break;
	end;
	while not(ThreadFinished = MaxThreads) do;
end;

end.

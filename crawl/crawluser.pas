unit CrawlUser;

interface
procedure CrawlUserGet(UserName : String);

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	sysutils,
	CrawlProject;

type
	TThreadParams = record
		ID : String;
	end;
	PThreadParams = ^TThreadParams;

const
	MaxLimits : Integer = 20;
	MaxThreads : Integer = 64;

var
	Finished : Integer;

function ThreadEntry(P : Pointer) : Ptrint;
var
	Params : PThreadParams;
begin
	Params := P;

	CrawlProjectGet(Params^.ID);

	Dispose(Params);

	InterLockedIncrement(Finished);

	ThreadEntry := 0;
end;

procedure CrawlUserGet(UserName : String);
var
	JStr : String;
	JData, JItem, JID : TJSONData;
	N : Integer;
	I : Integer;
	Param : PThreadParams;
	Params : Array of PThreadParams;
begin
	N := 0;

	SetLength(Params, 0);

	WriteLn(StdErr, '[' + UserName + '] Populating...');
	while true do
	begin
		while true do
		begin
			try JStr := TFPHTTPClient.SimpleGet('https://api.scratch.mit.edu/users/' + UserName + '/projects?limits=' + IntToStr(MaxLimits) + '&offset=' + IntToStr(N));
			except
				continue;
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
	
	Finished := MaxThreads;
	for I := 0 to Length(Params) - 1 do
	begin
		InterLockedDecrement(Finished);

		BeginThread(@ThreadEntry, Params[I]);

		while Finished = 0 do;
	end;
	while not(Finished = MaxThreads) do;
end;

end.

unit CrawlUser;

interface
procedure CrawlUserGet(UserName : String);

implementation
uses
	CrawlProject,
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	sysutils;

type
	TThreadParams = record
		ID : String;
	end;
	PThreadParams = ^TThreadParams;

const
	MaxLimits : Integer = 16;

var
	Finished : Integer;

function ThreadEntry(P : Pointer) : Ptrint;
var
	Params : PThreadParams;
begin
	Params := P;

	CrawlProjectGet(Params^.ID);

	Dispose(Params);

	ThreadEntry := 0;

	InterLockedIncrement(Finished);
end;

procedure CrawlUserGet(UserName : String);
var
	JStr : String;
	JData, JItem, JID : TJSONData;
	N : Integer;
	I : Integer;
	Params : PThreadParams;
begin
	N := 0;

	while true do
	begin
		while true do
		begin
			try JStr := TFPHttpClient.SimpleGet('https://api.scratch.mit.edu/users/' + UserName + '/projects?limits=' + IntToStr(MaxLimits) + '&offset=' + IntToStr(N));
			except
				continue;
			end;
			break;
		end;
		JData := GetJSON(JStr);

		if JData.Count = 0 then
		begin
			JData.Free();
			break;
		end;

		Finished := 0;
		for I := 0 to JData.Count - 1 do
		begin
			JItem := JData.Items[I];
			JID := JItem.FindPath('id');

			if Assigned(JID) then
			begin
				New(Params);
				Params^.ID := JID.AsString;

				BeginThread(@ThreadEntry, Params);
			end;
		end;
		while Finished < JData.Count do;

		JData.Free();

		N := N + MaxLimits;
	end;
end;

end.

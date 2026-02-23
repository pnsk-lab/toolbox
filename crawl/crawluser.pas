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

procedure CrawlUserGet(UserName : String);
var
	JStr : String;
	JData, JItem, JID : TJSONData;
	N : Integer;
	I : Integer;
begin
	N := 0;

	while true do
	begin
		JStr := TFPHttpClient.SimpleGet('https://api.scratch.mit.edu/users/' + UserName + '/projects?limits=20&offset=' + IntToStr(N));
		JData := GetJSON(JStr);

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
				CrawlProjectGet(JID.AsString);
			end;
		end;

		JData.Free();

		N := N + 20;
	end;
end;

end.

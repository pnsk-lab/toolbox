unit AxeDatabase;

interface
type
	TAxeDatabaseEntry = record
		ProjectID : Integer;
		Title : String;
		Description : String;
		Instructions : String;
		AuthorID : Integer;
		AuthorName : String;
		Timestamp : String;
		SharedTimestamp : String;
	end;

procedure AxeDatabaseConnect(HostName : String; Port : String);
procedure AxeDatabaseAdd(Entry : TAxeDatabaseEntry; Overwrite : Boolean = True);

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	classes,
	sysutils;

var
	DBHostName : String;
	DBPort : String;

procedure AxeDatabaseConnect(HostName : String; Port : String);
begin
	DBHostName := HostName;
	DBPort := Port;
end;

procedure AxeDatabaseAdd(Entry : TAxeDatabaseEntry; Overwrite : Boolean = True);
var
	Client : TFPHTTPClient;
	JData, JNumFound : TJSONData;
	JObj : TJSONObject;
	JStr : String;
begin
{$ifndef DATABASE}
	exit;
{$endif}

	if Overwrite then
	begin
		JData := GetJSON('{}');
		JObj := JData as TJSONObject;

		JObj.Add('delete', GetJSON('{"query":"project_id:' + IntToStr(Entry.ProjectID) + '"}'));

		while true do
		begin
			Client := TFPHTTPClient.Create(nil);

			try
				Client.AddHeader('Content-Type', 'application/json');
				Client.RequestBody := TRawByteStringStream.Create(JData.AsJSON);
				Client.Post('http://' + DBHostName + ':' + DBPort + '/solr/toolbox/update?commit=true');
			except
				Client.Free();
				continue;
			end;
			Client.Free();
			break;
		end;

		JData.Free();
	end
	else
	begin
		while true do
		begin
			try JStr := TFPHTTPClient.SimpleGet('http://' + DBHostName + ':' + DBPort + '/solr/toolbox/select?q=project_id%3A' + IntToStr(Entry.ProjectID));
			except
				continue;
			end;
			break;
		end;

		JData := GetJSON(JStr);
		JNumFound := JData.FindPath('response.numFound');

		if Assigned(JNumFound) then
		begin
			if JNumFound.AsInteger > 0 then exit;
		end;
	end;

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	JObj.Add('project_id', Entry.ProjectID);
	JObj.Add('title', Entry.Title);
	JObj.Add('description', Entry.Description);
	JObj.Add('instructions', Entry.Instructions);
	JObj.Add('author_id', Entry.AuthorID);
	JObj.Add('author_name', Entry.AuthorName);
	JObj.Add('author_search_name', Entry.AuthorName);
	JObj.Add('timestamp', Entry.Timestamp);
	JObj.Add('shared_timestamp', Entry.SharedTimestamp);

	while true do
	begin
		Client := TFPHTTPClient.Create(nil);

		try
			Client.AddHeader('Content-Type', 'application/json');
			Client.RequestBody := TRawByteStringStream.Create(JData.AsJSON);
			Client.Post('http://' + DBHostName + ':' + DBPort + '/api/collections/toolbox/update');
		except
			Client.Free();
			continue;
		end;
		Client.Free();
		break;
	end;

	JData.Free();
end;

end.

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
	end;

procedure AxeDatabaseConnect(HostName : String; Port : String);
procedure AxeDatabaseAdd(Entry : TAxeDatabaseEntry);

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

procedure AxeDatabaseAdd(Entry : TAxeDatabaseEntry);
var
	Client : TFPHTTPClient;
	JData : TJSONData;
	JObj : TJSONObject;
begin
{$ifndef DATABASE}
	Exit;
{$endif}

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	JObj.Add('delete', GetJSON('{"query":"project_id:' + IntToStr(Entry.ProjectID) + '"}'));

	while true do
	begin
		Client := TFPHTTPClient.Create(nil);

		try
			Client.AddHeader('Content-Type', 'application/json');
			Client.RequestBody := TRawByteStringStream.Create(JData.AsJSON);
			Client.Post('http://' + DBHostName + ':' + DBPort + '/solr/crawl/update?commit=true');
		except
			Client.Free();
			continue;
		end;
		Client.Free();
		break;
	end;

	JData.Free();

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	JObj.Add('project_id', Entry.ProjectID);
	JObj.Add('title', Entry.Title);
	JObj.Add('description', Entry.Description);
	JObj.Add('instructions', Entry.Instructions);
	JObj.Add('author_id', Entry.AuthorID);
	JObj.Add('author_name', Entry.AuthorName);
	JObj.Add('timestamp', Entry.Timestamp);

	while true do
	begin
		Client := TFPHTTPClient.Create(nil);

		try
			Client.AddHeader('Content-Type', 'application/json');
			Client.RequestBody := TRawByteStringStream.Create(JData.AsJSON);
			Client.Post('http://' + DBHostName + ':' + DBPort + '/api/collections/crawl/update');
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

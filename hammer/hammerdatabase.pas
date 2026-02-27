unit HammerDatabase;

interface
type
	THammerDatabaseEntry = record
		NumFound : Integer;
		ProjectID : Integer;
		Title : String;
		Description : String;
		Instructions : String;
		AuthorID : Integer;
		AuthorName : String;
		Timestamp : String;
		SharedTimestamp : String;
	end;
	THammerDatabaseEntryArray = Array of THammerDatabaseEntry;

const
	HammerDatabaseMaxQuery : Integer = 20;

procedure HammerDatabaseConnect(HostName : String; Port : String);
function HammerDatabaseQuery(Project : Integer; Offset : Integer = 0) : THammerDatabaseEntryArray;
function HammerDatabaseQuery(Query : String; Offset : Integer = 0) : THammerDatabaseEntryArray;
function HammerDatabaseQueryUserName(UserName : String; Offset : Integer = 0) : THammerDatabaseEntryArray;
function HammerDatabaseQueryRandom() : THammerDatabaseEntryArray;

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	classes,
	sysutils,
	dateutils;

var
	DBHostName : String;
	DBPort : String;

procedure HammerDatabaseConnect(HostName : String; Port : String);
begin
	DBHostName := HostName;
	DBPort := Port;
end;

function EscapeSimple(Value : String) : String;
begin
	EscapeSimple := Value;
	EscapeSimple := StringReplace(EscapeSimple, '"', '\\', [rfReplaceAll]);
	EscapeSimple := StringReplace(EscapeSimple, '"', '\"', [rfReplaceAll]);
end;

function Escape(Field : String; Query : String) : String;
var
	I : Integer;
	S : String;
	DQ : Boolean;
	E : String;
	Esc : Boolean;
begin
	E := Query;

	Escape := '';

	DQ := false;
	S := '';
	Esc := false;
	for I := 1 to Length(E) + 1 do
	begin
		if not(I = (Length(E) + 1)) and Esc then
		begin
			S := S + Copy(E, I, 1);

			Esc := false;
			continue;
		end;

		if (I = (Length(E) + 1)) or (not(DQ) and (Copy(E, I, 1) = ' ')) then
		begin
			Escape := Escape + Field + ':"' + S + '" ';

			S := '';
		end
		else if Copy(E, I, 1) = '\' then
		begin
			Esc := true;
		end
		else if Copy(E, I, 1) = '"' then
		begin
			DQ := not(DQ);
		end
		else
		begin
			S := S + Copy(E, I, 1);
		end;
	end;
end;

function JSONToRecord(JData : TJSONData) : THammerDatabaseEntryArray;
var
	JItem, TNumFound : TJSONData;
	JObj : TJSONObject;
	JArr : TJSONArray;
	I : Integer;
begin
	JSONToRecord := [];
	
	JObj := JData as TJSONObject;

	JArr := JObj.FindPath('response.docs') as TJSONArray;
	if Assigned(JArr) then
	begin
		TNumFound := JObj.FindPath('response.numFound');

		SetLength(JSONToRecord, JArr.Count);

		for I := 0 to JArr.Count - 1 do
		begin
			JObj := JArr.Items[I] as TJSONObject;

			if Assigned(TNumFound) then JSONToRecord[I].NumFound := TNumFound.AsInteger;

			JSONToRecord[I].ProjectID := JObj.FindPath('project_id').AsInteger;

			JItem := JObj.FindPath('title');
			JSONToRecord[I].Title := '';
			if Assigned(JItem) then JSONToRecord[I].Title := JObj.FindPath('title').AsString;

			JItem := JObj.FindPath('description');
			JSONToRecord[I].Description := '';
			if Assigned(JItem) then JSONToRecord[I].Description := JItem.AsString;

			JItem := JObj.FindPath('instructions');
			JSONToRecord[I].Instructions := '';
			if Assigned(JItem) then JSONToRecord[I].Instructions := JItem.AsString;

			JItem := JObj.FindPath('author_id');
			JSONToRecord[I].AuthorID := 0;
			if Assigned(JItem) then JSONToRecord[I].AuthorID := JItem.AsInteger;

			JItem := JObj.FindPath('author_name');
			JSONToRecord[I].AuthorName := '';
			if Assigned(JItem) then JSONToRecord[I].AuthorName := JItem.AsString;

			JItem := JObj.FindPath('timestamp');
			JSONToRecord[I].Timestamp := '';
			if Assigned(JItem) then JSONToRecord[I].Timestamp := JItem.AsString;

			JItem := JObj.FindPath('shared_timestamp');
			JSONToRecord[I].SharedTimestamp := '';
			if Assigned(JItem) then JSONToRecord[I].SharedTimestamp := JItem.AsString;
		end;
	end;
end;

function SendJSON(JData : TJSONData) : String;
var
	Client : TFPHTTPClient;
begin
	SendJSON := '';

	while true do
	begin
		Client := TFPHTTPClient.Create(nil);
		try
			Client.AddHeader('Content-Type', 'application/json');
			Client.RequestBody := TRawByteStringStream.Create(JData.AsJSON);
			SendJSON := Client.Post('http://' + DBHostName + ':' + DBPort + '/solr/toolbox/query');
		except
			Client.Free();
			continue;
		end;
		if not(Client.ResponseStatusCode = 200) then
		begin
			Client.Free();
			continue;
		end;
		Client.Free();
		break;
	end;
end;

function HammerDatabaseQuery(Project : Integer; Offset : Integer = 0) : THammerDatabaseEntryArray;
var
	JStr : String;
	JData : TJSONData;
	JObj : TJSONObject;
begin
	HammerDatabaseQuery := [];

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	JObj.Add('query', 'project_id:' + IntToStr(Project));
	JObj.Add('limit', HammerDatabaseMaxQuery);
	JObj.Add('offset', Offset);
	JObj.Add('sort', 'shared_timestamp desc');

	JStr := SendJSON(JData);

	JData.Free();

	JData := GetJSON(JStr, false);
	HammerDatabaseQuery := JSONToRecord(JData);
	JData.Free();
end;

function HammerDatabaseQuery(Query : String; Offset : Integer = 0) : THammerDatabaseEntryArray;
var
	JStr : String;
	JData : TJSONData;
	JObj : TJSONObject;
	Q : String;
begin
	HammerDatabaseQuery := [];

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	Q := '';
	Q := Q + Escape('title', Query) + ' ';
	Q := Q + Escape('description', Query) + ' ';
	Q := Q + Escape('instructions', Query) + ' ';
	Q := Q + Escape('author_search_name', Query) + ' ';

	JObj.Add('query', Q);
	JObj.Add('limit', HammerDatabaseMaxQuery);
	JObj.Add('offset', Offset);
	JObj.Add('sort', 'shared_timestamp desc');

	JStr := SendJSON(JData);

	JData.Free();

	JData := GetJSON(JStr, false);
	HammerDatabaseQuery := JSONToRecord(JData);
	JData.Free();
end;

function HammerDatabaseQueryUserName(UserName : String; Offset : Integer = 0) : THammerDatabaseEntryArray;
var
	JStr : String;
	JData : TJSONData;
	JObj : TJSONObject;
begin
	HammerDatabaseQueryUserName := [];

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	JObj.Add('query', 'author_name:"' + EscapeSimple(UserName) + '"');
	JObj.Add('limit', HammerDatabaseMaxQuery);
	JObj.Add('offset', Offset);
	JObj.Add('sort', 'shared_timestamp desc');

	JStr := SendJSON(JData);

	JData.Free();

	JData := GetJSON(JStr, false);
	HammerDatabaseQueryUserName := JSONToRecord(JData);
	JData.Free();
end;

function HammerDatabaseQueryRandom() : THammerDatabaseEntryArray;
var
	JStr : String;
	JData : TJSONData;
	JObj : TJSONObject;
begin
	HammerDatabaseQueryRandom := [];

	JData := GetJSON('{}');
	JObj := JData as TJSONObject;

	JObj.Add('query', '*:*');
	JObj.Add('limit', 1);
	JObj.Add('offset', 0);
	JObj.Add('sort', 'random_' + IntToStr(Random(DateTimeToUnix(Now()))) + ' desc');

	JStr := SendJSON(JData);

	JData.Free();

	JData := GetJSON(JStr, false);
	HammerDatabaseQueryRandom := JSONToRecord(JData);
	JData.Free();
end;

end.

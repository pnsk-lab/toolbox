unit HammerSearch;

interface
uses
	httpdefs,
	HammerUtility,
	HammerInfo;

procedure HammerSearchProcess(Vars : THammerStringMap; Query : THammerStringMap; Req : TRequest; Res : TResponse);

implementation
uses
	HammerDatabase,
	sysutils;

function GetThumbnail(Entry : THammerDatabaseEntry) : String;
const
	TryThem : Array of String = ('png', 'gif', 'jpg', 'jpeg');
var
	I : Integer;
	Path : String;
begin
	GetThumbnail := '';

	for I := 0 to Length(TryThem) - 1 do
	begin
		Path := HammerInfoDirectory + '/projects/' + IntToStr(Entry.ProjectID) + '/' + StringReplace(Entry.Timestamp, ':', '-', [rfReplaceAll]) + '/thumbnail.' + TryThem[I];

		if FileExists(Path) then
		begin
			GetThumbnail := 'projects/' + IntToStr(Entry.ProjectID) + '/' + StringReplace(Entry.Timestamp, ':', '-', [rfReplaceAll]) + '/thumbnail.' + TryThem[I];
			exit;
		end;
	end;
end;

procedure HammerSearchProcess(Vars : THammerStringMap; Query : THammerStringMap; Req : TRequest; Res : TResponse);
var
	Q : String;
	R : THammerDatabaseEntryArray;
	I : Integer;
	S : String;
begin
	Q := '';

	if not(Query.IndexOf('q') = -1) then Q := Query['q'];

	R := HammerDatabaseQuery(Q);

	S := '';
	for I := 0 to Length(R) - 1 do
	begin
		if (I mod 4) = 0 then S := S + '<tr height="225">' + #13#10;
		S := S + '	<td width="25%">' + #13#10;
		S := S + '		<table border="0" cellspacing="0" cellpadding="0" width="100%" height="100%">' + #13#10;
		S := S + '			<tr height="150">' + #13#10;
		S := S + '				<td valign="top" align="center">' + #13#10;
		S := S + '					<img src="/data/' + GetThumbnail(R[I]) + '" alt="Thumbnail" width="200px">' + #13#10;
		S := S + '				</td>' + #13#10;
		S := S + '			</tr>' + #13#10;
		S := S + '			<tr>' + #13#10;
		S := S + '				<td align="center">' + #13#10;
		S := S + '					' + R[I].Title + #13#10;
		S := S + '				</td>' + #13#10;
		S := S + '			</tr>' + #13#10;
		S := S + '		</table>' + #13#10;
		S := S + '	</td>' + #13#10;
		if ((I mod 4) = 3) then S := S + '</tr>' + #13#10;
	end;
	for I := (I mod 4) + 1 to 3 do S := S + '<td width="25%"></td>' + #13#10;
	if not((I mod 4) = 3) then S := S + '</tr>' + #13#10;

	Vars['SEARCH_RESULT'] := S;
end;

end.

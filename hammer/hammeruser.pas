unit HammerUser;

interface
uses
	httpdefs,
	HammerUtility,
	HammerInfo;

procedure HammerUserProcess(Vars : THammerStringMap; Query : THammerStringMap; Req : TRequest; Res : TResponse);

implementation
uses
	sysutils,
	fpjson,
	jsonparser,
	classes,
	HammerDatabase;

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

function GetIcon(User : String) : String;
const
	TryThem : Array of String = ('png', 'gif', 'jpg', 'jpeg');
var
	I : Integer;
	Path : String;
begin
	GetIcon := '';

	for I := 0 to Length(TryThem) - 1 do
	begin
		Path := HammerInfoDirectory + '/users/' + User + '/icon.' + TryThem[I];

		if FileExists(Path) then
		begin
			GetIcon := 'users/' + User + '/icon.' + TryThem[I];
			exit;
		end;
	end;
end;

procedure HammerUserProcess(Vars : THammerStringMap; Query : THammerStringMap; Req : TRequest; Res : TResponse);
var
	U : String;
	R : THammerDatabaseEntryArray;
	I, P : Integer;
	S, S2 : String;
	Pages : Integer;
	FS : TFileStream;
	JData, JItem : TJSONData;
begin
	P := 1;
	U := '';

	if not(Query.IndexOf('u') = -1) then U := Query['u'];

	try
		if not(Query.IndexOf('p') = -1) then P := StrToInt(Query['p']);
	except
	end;

	if P < 1 then P := 1;

	R := HammerDatabaseQueryUserName(U, (P - 1) * HammerDatabaseMaxQuery);

	S := '';
	for I := 0 to Length(R) - 1 do
	begin
		if (I mod 4) = 0 then S := S + '<tr>' + #13#10;
		S := S + '	<td width="25%">' + #13#10;
		S := S + '		<table border="0" cellspacing="0" cellpadding="0" width="100%">' + #13#10;
		S := S + '			<tr>' + #13#10;
		S := S + '				<td valign="top" align="center" height="175">' + #13#10;
		S := S + '					<a href="/project?p=' + IntToStr(R[I].ProjectID) + '"><img src="/data/' + GetThumbnail(R[I]) + '" alt="Thumbnail" width="200px" border="0"></a>' + #13#10;
		S := S + '				</td>' + #13#10;
		S := S + '			</tr>' + #13#10;
		S := S + '			<tr>' + #13#10;
		S := S + '				<td align="center" height="25">' + #13#10;
		S := S + '					<a href="/project?p=' + IntToStr(R[I].ProjectID) + '">' + R[I].Title + '</a><br>' + #13#10;
		S := S + '				</td>' + #13#10;
		S := S + '			</tr>' + #13#10;
		S := S + '		</table>' + #13#10;
		S := S + '	</td>' + #13#10;
		if ((I mod 4) = 3) then
		begin
			S := S + '</tr>' + #13#10;
			S := S + '<tr>' + #13#10;
			S := S + '	<td colspan="4" height="10"></td>' + #13#10;
			S := S + '</tr>' + #13#10;
		end;
	end;
	O := I;
	if O > 0 then
	begin
		for I := (O mod 4) + 1 to 3 do S := S + '<td width="25%"></td>' + #13#10;
		if not((O mod 4) = 3) then S := S + '</tr>' + #13#10;
	end;
	Vars['USER_RESULT'] := S;
	Vars['USER_ICON'] := GetIcon(U);

	try
		FS := TFileStream.Create(HammerInfoDirectory + '/users/' + U + '/info.json', fmOpenRead or fmShareDenyWrite);
		JData := GetJSON(FS, false);

		JItem := JData.FindPath('profile.bio');
		if Assigned(JItem) then Vars['USER_BIO'] := JItem.AsString;
		JItem := JData.FindPath('profile.status');
		if Assigned(JItem) then Vars['USER_STATUS'] := JItem.AsString;

		JData.Free();
		FS.Free();
	except
	end;

	S2 := '';
	if Length(R) > 0 then
	begin
		Pages := R[0].NumFound div HammerDatabaseMaxQuery;
		if not((Pages * HammerDatabaseMaxQuery) = R[0].NumFound) then Pages := Pages + 1;

		if P > 1 then
		begin
			S2 := S2 + '<a href="?u=' + HTTPEncode(U) + '&amp;p=' + IntToStr(1) + '">&lt;&lt;</a> ';
			S2 := S2 + '<a href="?u=' + HTTPEncode(U) + '&amp;p=' + IntToStr(P - 1) + '">&lt;</a> ';
		end;

		for I := 1 to Pages do
		begin
			if I = P then
			begin
				S2 := S2 + ' <b>' + IntToStr(I) + '</b> ';
			end
			else
			begin
				S2 := S2 + ' <a href="?u=' + HTTPEncode(U) + '&amp;p=' + IntToStr(I) + '">' + IntToStr(I) + '</a> ';
			end;
		end;

		if P < Pages then
		begin
			S2 := S2 + ' <a href="?u=' + HTTPEncode(U) + '&amp;p=' + IntToStr(P + 1) + '">&gt;</a>';
			S2 := S2 + ' <a href="?u=' + HTTPEncode(U) + '&amp;p=' + IntToStr(Pages) + '">&gt;&gt;</a>';
		end;
	end;
	Vars['USER_PAGES'] := S2;
end;

end.

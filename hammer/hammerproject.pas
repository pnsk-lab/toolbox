unit HammerProject;

interface
uses
	httpdefs,
	HammerUtility;

procedure HammerProjectProcess(Vars : THammerStringMap; Query : THammerStringMap; Req : TRequest; Res : TResponse);

implementation
uses
	HammerDatabase,
	sysutils;

procedure HammerProjectProcess(Vars : THammerStringMap; Query : THammerStringMap; Req : TRequest; Res : TResponse);
var
	P : Integer;
	Arr : THammerDatabaseEntryArray;
begin
	P := 0;

	try
		if not(Query.IndexOf('p') = -1) then P := StrToInt(Query['p']);
	except
	end;

	Arr := HammerDatabaseQuery(P);

	if Length(Arr) > 0 then
	begin
		Vars['PROJECT_TITLE'] := Arr[0].Title;
		Vars['PROJECT_DESCRIPTION'] := Arr[0].Description;
		Vars['PROJECT_INSTRUCTIONS'] := Arr[0].Instructions;
		Vars['PROJECT_AUTHOR'] := Arr[0].AuthorName;
		Vars['PROJECT_TIMESTAMP'] := Arr[0].Timestamp;
	end;
end;

end.

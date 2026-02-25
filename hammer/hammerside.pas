unit HammerSide;

interface
uses
	httpdefs;

function HammerSideProcess(Req : TRequest; Res : TResponse; FileName : String) : String;

implementation
uses
	sysutils,
	classes,
	strutils,
	fgl,
	HammerUtility;

function ParseCommand(Command : String) : THammerStringArray;
var
	S : String;
	DQ : Boolean;
	SQ : Boolean;
	I : Integer;
	E : Boolean;
	C : String;
begin
	ParseCommand := [];

	S := '';
	DQ := false;
	SQ := false;
	E := true;

	for I := 1 to Length(Command) do
	begin
		C := Copy(Command, I, 1);

		if not(DQ) and not(SQ) and (C = ' ') then
		begin
			Insert(S, ParseCommand, Length(ParseCommand));

			S := '';
			E := true;
		end
		else if not(SQ) and (C = '"') then
		begin
			DQ := not(DQ);
			E := false;
		end
		else if not(DQ) and (C = '''') then
		begin
			SQ := not(SQ);
			E := false;
		end
		else
		begin
			S := S + C;
			E := false;
		end;
	end;

	if not(E) then
	begin
		Insert(S, ParseCommand, Length(ParseCommand));
	end;
end;

function GetCommandArgument(Arguments : THammerStringArray; Argument : String) : String;
var
	I : Integer;
begin
	GetCommandArgument := '';

	for I := 1 to Length(Arguments) - 1 do
	begin
		if StartsText(Argument + '=', Arguments[I]) then
		begin
			GetCommandArgument := Copy(Arguments[I], Length(Argument) + 2);
			break;
		end;
	end;
end;

function Expression(Vars : THammerStringMap; Expr : String) : Integer;
var
	Arr : THammerStringArray;
	ArrResult : String;
begin
	Expression := 0;

	Arr := ParseCommand(Expr);

	if Length(Arr) = 3 then
	begin
		if Copy(Arr[0], 1, 1) = '$' then
		begin
			ArrResult := '';
			Vars.TryGetData(Copy(Arr[0], 2), ArrResult);
			Arr[0] := ArrResult;
		end;
		if Copy(Arr[2], 1, 1) = '$' then
		begin
			ArrResult := '';
			Vars.TryGetData(Copy(Arr[2], 2), ArrResult);
			Arr[2] := ArrResult;
		end;

		if Arr[1] = '=' then
		begin
			if Arr[0] = Arr[2] then
			begin
				Expression := 1;
			end;
		end;
	end;
end;

function HammerSideProcess(Req : TRequest; Res : TResponse; FileName : String) : String;
var
	TF : TextFile;
	Lines : Array of String;
	LineStr : String;
	I : Integer;
	Arr : Array of String;
	Vars : THammerStringMap;
	Param, ParamResult : String;
	Stack : Array of Integer;
	V : Integer;
	AfterNL : Boolean;
	BeforeNL : Boolean;
	Escape : Boolean;
	Query : THammerStringMap;
begin
	AssignFile(TF, FileName);

	try Reset(TF);
	except
		on E : EInOutError do
		begin
			E.Message := 'Unable to open file "' + FileName + '": ' + E.Message;
			raise;
		end;
		on E : Exception do
		begin
			raise;
		end;
	end;

	SetLength(Lines, 0);
	repeat
		ReadLn(TF, LineStr);

		Insert(LineStr, Lines, Length(Lines));
	until EOF(TF);

	Vars := THammerStringMap.Create();
	Vars['PATH_INFO'] := Req.PathInfo;
	Vars['QUERY_STRING'] := Req.QueryString;
	Vars['STATUS_CODE'] := '200';
	Vars['STATUS_TEXT'] := 'OK';

	Query := HammerUtilityParseQuery(Req.QueryString);
	for I := 0 to Query.Count - 1 do
	begin
		Vars['QUERY_STRING_' + UpperCase(Query.Keys[I])] := Query[Query.Keys[I]];
	end;

	SetLength(Stack, 1);

	{
		if it's 0 - false
		        1 - true
		        2 - skip below
	}
	Stack[0] := 1;
	HammerSideProcess := '';
	for I := 0 to Length(Lines) - 1 do
	begin
		LineStr := Trim(Lines[I]);
		if StartsText('<!--#', LineStr) and EndsText('-->', LineStr) then
		begin
			LineStr := Trim(Copy(LineStr, 6, Length(LineStr) - 3 - 6));

			Arr := ParseCommand(LineStr);
			if Arr[0] = 'if' then
			begin
				if Stack[Length(Stack) - 1] = 1 then
				begin
					Insert(Expression(Vars, GetCommandArgument(Arr, 'expr')), Stack, Length(Stack));
				end
				else
				begin
					Insert(2, Stack, Length(Stack));
				end;
			end
			else if Arr[0] = 'elif' then
			begin
				if Stack[Length(Stack) - 1] = 0 then
				begin
					Insert(Expression(Vars, GetCommandArgument(Arr, 'expr')), Stack, Length(Stack));
				end
				else
				begin
					Insert(2, Stack, Length(Stack));
				end;
				Delete(Stack, Length(Stack) - 2, 1);
			end
			else if Arr[0] = 'else' then
			begin
				if Stack[Length(Stack) - 1] = 0 then
				begin
					Insert(1, Stack, Length(Stack));
				end
				else
				begin
					Insert(2, Stack, Length(Stack));
				end;
				Delete(Stack, Length(Stack) - 2, 1);
			end
			else if Arr[0] = 'endif' then
			begin
				Delete(Stack, Length(Stack) - 1, 1);
			end
			else if not(Stack[Length(Stack) - 1] = 1) then
			begin
			end
			else if Arr[0] = 'echo' then
			begin
				BeforeNL := true;
				AfterNL := true;
				if not((GetCommandArgument(Arr, 'nonl') = '') or (GetCommandArgument(Arr, 'nonl') = 'false')) then
				begin
					BeforeNL := false;
					AfterNL := false;
				end;
				if GetCommandArgument(Arr, 'beforenl') = 'false' then
				begin
					BeforeNL := false;
				end;
				if GetCommandArgument(Arr, 'afternl') = 'false' then
				begin
					AfterNL := false;
				end;

				Param := GetCommandArgument(Arr, 'var');
				if Param = '' then
				begin
					Param := GetCommandArgument(Arr, 'varesc');

					if not(Param = '') then Escape := true;
				end;

				if Vars.TryGetData(Param, ParamResult) then
				begin
					if Escape then
					begin
						ParamResult := StringReplace(ParamResult, '&', '&amp;',  [rfReplaceAll]);
						ParamResult := StringReplace(ParamResult, '"', '&quot;',  [rfReplaceAll]);
						ParamResult := StringReplace(ParamResult, '<', '&lt;',  [rfReplaceAll]);
						ParamResult := StringReplace(ParamResult, '>', '&gt;',  [rfReplaceAll]);
					end;

					if not(BeforeNL) and (Copy(HammerSideProcess, Length(HammerSideProcess) - 1, 2) = #13#10) then
					begin
						HammerSideProcess := Copy(HammerSideProcess, 1, Length(HammerSideProcess) - 2);
					end;
					HammerSideProcess := HammerSideProcess + ParamResult;
				end;

				if AfterNL then HammerSideProcess := HammerSideProcess + #13#10;
			end
			else if Arr[0] = 'set' then
			begin
				Vars[GetCommandArgument(Arr, 'var')] := GetCommandArgument(Arr, 'value');
			end
			else if Arr[0] = 'include' then
			begin
				HammerSideProcess := HammerSideProcess + HammerSideProcess(Req, Res, ExtractFilePath(FileName) + GetCommandArgument(Arr, 'file'));
			end;
		end
		else
		begin
			HammerSideProcess := HammerSideProcess + Lines[I] + #13#10;
		end;
	end;

	Res.Code := StrToInt(Vars['STATUS_CODE']);
	Res.CodeText := Vars['STATUS_TEXT'];

	Vars.Free();

	CloseFile(TF);
end;

end.

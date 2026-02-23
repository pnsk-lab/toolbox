unit CrawlServerSide;

interface
uses
	httpdefs;

procedure CrawlServerSideProcess(Req : TRequest; Res : TResponse; FileName : String);

implementation
uses
	sysutils,
	classes,
	strutils,
	fgl;

type
	TStringMap = specialize TFPGMap<String, String>;
	TStringArray = Array of String;

function ParseCommand(Command : String) : TStringArray;
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

function GetCommandArgument(Arguments : TStringArray; Argument : String) : String;
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

function Expression(Vars : TStringMap; Expr : String) : Integer;
var
	Arr : TStringArray;
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

procedure CrawlServerSideProcess(Req : TRequest; Res : TResponse; FileName : String);
var
	TF : TextFile;
	Lines : Array of String;
	LineStr : String;
	I : Integer;
	Arr : Array of String;
	Vars : TStringMap;
	Param, ParamResult : String;
	Stack : Array of Integer;
	V : Integer;
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

	Vars := TStringMap.Create();
	Vars['PATH_INFO'] := Req.PathInfo;
	Vars['STATUS_CODE'] := '200';
	Vars['STATUS_TEXT'] := 'OK';

	SetLength(Stack, 1);

	// if it's 0 - false
	//         1 - true
	//         2 - skip below
	Stack[0] := 1;
	for I := 0 to Length(Lines) - 1 do
	begin
		LineStr := Trim(Lines[I]);
		if StartsText('<!--#', LineStr) and EndsText('-->', LineStr) then
		begin
			LineStr := Trim(Copy(LineStr, 6, Length(LineStr) - 3 - 6));

			Arr := ParseCommand(LineStr);
			if (Arr[0] = 'if') and (Length(Arr) = 2) then
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
			else if (Arr[0] = 'elif') and (Length(Arr) = 2) then
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
			else if (Arr[0] = 'else') and (Length(Arr) = 1) then
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
			else if (Arr[0] = 'endif') and (Length(Arr) = 1) then
			begin
				Delete(Stack, Length(Stack) - 1, 1);
			end
			else if not(Stack[Length(Stack) - 1] = 1) then
			begin
			end
			else if (Arr[0] = 'echo') and (Length(Arr) = 2) then
			begin
				Param := GetCommandArgument(Arr, 'var');

				if Vars.TryGetData(Param, ParamResult) then
				begin
					Res.Content := Res.Content + ParamResult + #13#10;
				end;
			end
			else if (Arr[0] = 'set') and (Length(Arr) = 3) then
			begin
				Vars[GetCommandArgument(Arr, 'var')] := GetCommandArgument(Arr, 'value');
			end
			else if (Arr[0] = 'include') and (Length(Arr) = 2) then
			begin
				CrawlServerSideProcess(Req, Res, ExtractFilePath(FileName) + GetCommandArgument(Arr, 'file'));
			end;
		end
		else
		begin
			Res.Content := Res.Content + Lines[I] + #13#10;
		end;
	end;

	Res.Code := StrToInt(Vars['STATUS_CODE']);
	Res.CodeText := Vars['STATUS_TEXT'];

	Vars.Free();

	CloseFile(TF);
end;

end.

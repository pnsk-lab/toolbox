unit AxeUtility;

interface
var
	AxeUtilityShutdown : Boolean;

function AxeUtilityGetExtension(URL : String) : String;

implementation
function AxeUtilityGetExtension(URL : String) : String;
var
	I : Integer;
begin
	AxeUtilityGetExtension := '';

	I := Length(URL);
	while I >= 1 do
	begin
		if Copy(URL, I, 1) = '.' then
		begin
			AxeUtilityGetExtension := Copy(URL, I + 1);
			break;
		end;

		I := I - 1;
	end;

	for I := 1 to Length(AxeUtilityGetExtension) do
	begin
		if AxeUtilityGetExtension[I] = '?' then
		begin
			AxeUtilityGetExtension := Copy(AxeUtilityGetExtension, 1, I - 1);
		end;
	end;
end;

end.

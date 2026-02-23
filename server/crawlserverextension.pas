unit CrawlServerExtension;

interface
function CrawlServerExtensionGet(Path : String) : String;

implementation
type
	TExtension = record
		Extension : String;
		MIME : String;
	end;

const
	Extensions : Array of TExtension = (
		(
			Extension: 'png';
			MIME: 'image/png';
		),
		(
			Extension: 'svg';
			MIME: 'image/svg';
		),
		(
			Extension: 'jpeg';
			MIME: 'image/jpeg';
		),
		(
			Extension: 'jpg';
			MIME: 'image/jpeg';
		),
		(
			Extension: 'bmp';
			MIME: 'image/bmp';
		),
		(
			Extension: 'gif';
			MIME: 'image/gif';
		),
		(
			Extension: 'json';
			MIME: 'application/json';
		),
		(
			Extension: 'html';
			MIME: 'text/html';
		),
		(
			Extension: 'css';
			MIME: 'text/css';
		)
	);

function CrawlServerExtensionGet(Path : String) : String;
var
	I, J : Integer;
	Extension : String;
begin
	CrawlServerExtensionGet := 'application/octet-stream';

	I := Length(Path);
	while I >= 1 do
	begin
		if Path[I] = '.' then
		begin
			Extension := Copy(Path, I + 1);
			J := 0;
			while J < Length(Extensions) - 1 do
			begin
				if Extensions[J].Extension = Extension then
				begin
					CrawlServerExtensionGet := Extensions[J].MIME;
					break;
				end;

				J := J + 1;
			end;

			if not(J = (Length(Extensions) - 1)) then
			begin
				break;
			end;
		end;

		I := I - 1;
	end;
end;

end.

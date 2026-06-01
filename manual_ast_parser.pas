unit manual_ast_parser;

{$IFDEF FPC}{$MODE Delphi}{$ENDIF}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Menus;

type

  { TMainForm }

  TMainForm = class
  private
    function DelphiASTXmlToJson(const XmlText: string; FileNameOnly: string): string;
    function Parse(const FilePath: string; UseStringInterning: Boolean): string;
    function XmlToJson(const XmlText: string): string;
  end;

  function RunAst(fileName: String): String;
  function ParseUnitToJson(fileName: String): String;

implementation

uses
  {$IFNDEF FPC}
    StringUsageLogging, FastMM4,
  {$ENDIF}
  StringPool,
  DelphiAST, DelphiAST.Writer, DelphiAST.Classes,
  SimpleParser.Lexer.Types, IOUtils, Diagnostics,
  DelphiAST.SimpleParserEx,

  DOM, XMLRead,
  fpjson;

function RunAst(fileName: String): String;
var
  aspService: TMainForm;
begin
  aspService := TMainForm.Create;
  try
    result := aspService.Parse(fileName, false);
  finally
    aspService.Free;
  end;
end;

function ParseUnitToJson(fileName: String): String;
 var
   aspService: TMainForm;
 begin
   aspService := TMainForm.Create;
   try
     result := aspService.Parse(fileName, false);
   finally
     aspService.Free;
   end;
 end;

type
  TIncludeHandler = class(TInterfacedObject, IIncludeHandler)
  private
    FPath: string;
  public
    constructor Create(const Path: string);
    function GetIncludeFileContent(const ParentFileName, IncludeName: string;
      out Content: string; out FileName: string): Boolean;
  end;

{$IFNDEF FPC}
function MemoryUsed: Cardinal;
 var
   st: TMemoryManagerState;
   sb: TSmallBlockTypeState;
 begin
   GetMemoryManagerState(st);
   Result := st.TotalAllocatedMediumBlockSize + st.TotalAllocatedLargeBlockSize;
   for sb in st.SmallBlockTypeStates do
     Result := Result + sb.UseableBlockSize * sb.AllocatedBlockCount;
end;
{$ELSE}
function MemoryUsed: Cardinal;
begin
  Result := GetFPCHeapStatus.CurrHeapUsed;
end;
{$ENDIF}

function TMainForm.DelphiASTXmlToJson(const XmlText: string; FileNameOnly: string): string;

  function XmlNodeToJson(Node: TDOMNode): TJSONData;
  var
    Obj: TJSONObject;
    Arr: TJSONArray;
    I: Integer;
    Child: TDOMNode;
  begin
    Obj := TJSONObject.Create;

    // ✅ unikalny klucz
    Obj.Add('nodeName', Node.NodeName);

    // atrybuty XML
    if Node.Attributes <> nil then
      for I := 0 to Node.Attributes.Length - 1 do
        Obj.Add(
          Node.Attributes[I].NodeName,
          Node.Attributes[I].NodeValue
        );

    // dzieci
    Arr := TJSONArray.Create;
    Child := Node.FirstChild;
    while Child <> nil do
    begin
      if Child.NodeType = ELEMENT_NODE then
        Arr.Add(XmlNodeToJson(Child));
      Child := Child.NextSibling;
    end;

    if Arr.Count > 0 then
      Obj.Add('children', Arr)
    else
      Arr.Free;

    Result := Obj;
  end;

  function SanitizeXML(const S: string): string;
  var
    i: Integer;
    c: Char;
  begin
    Result := '';
    for i := 1 to Length(S) do
    begin
      c := S[i];
      if (Ord(c) = 9) or (Ord(c) = 10) or (Ord(c) = 13) or (Ord(c) >= 32) then
        Result := Result + c;
    end;
  end;

  procedure toFile(txt: string; dir_sufix: string = '');
  var
    SL: TStringList;
  begin
    SL := TStringList.Create;
    try
      SL.Text := txt;
      SL.SaveToFile('./output' + dir_sufix + '/' + FileNameOnly + '.json');
    finally
      SL.Free;
    end;
  end;

var
  Doc: TXMLDocument;
  Stream: TStringStream;
  Json: TJSONData;
  SanitizedInput: string;
begin
  SanitizedInput := SanitizeXML(XmlText);
  //dev
  //toFile(SanitizedInput, '_raw');
  try
    Stream := TStringStream.Create(SanitizedInput, TEncoding.UTF8);
    try
      try
        Stream.Position := 0;
        ReadXMLFile(Doc, Stream);
        try
          Json := XmlNodeToJson(Doc.DocumentElement);
          try
            Result := Json.FormatJSON;
            toFile(result);
          finally
            Json.Free;
          end;
        finally
          Doc.Free;
        end;
      except
        on e: Exception do
        begin
          toFile(SanitizedInput);
          raise;
        end;
      end;
    finally
      Stream.Free;
    end;
  except
    on e: Exception do
    begin
      raise;
    end;
  end;
end;

function TMainForm.Parse(const FilePath: string; UseStringInterning: Boolean): string;
var
  SyntaxTree: TSyntaxNode;
  memused: Cardinal;
  sw: TStopwatch;
  StringPool: TStringPool;
  OnHandleString: TStringEvent;
  Builder: TPasSyntaxTreeBuilder;
  StringStream: TStringStream;
  I: Integer;

  Xml, Json: string;
  FileNameOnly: string;
begin
    if UseStringInterning then
    begin
      StringPool := TStringPool.Create;
      OnHandleString := StringPool.StringIntern;
    end
    else
    begin
      StringPool := nil;
      OnHandleString := nil;
    end;

    memused := MemoryUsed;
    sw := TStopwatch.StartNew;
    try
      Builder := TPasSyntaxTreeBuilder.Create;

      // CIGNA_VER;DWS_NO_VCL;RDTSC;RPC_SERWER;RPC_KLIENT;USE_EWID;USE_REAS;USE_NADZ;MON_ACTIONS;LARGE_ADDRESS;
      Builder.AddDefine('CIGNA_VER');
      Builder.AddDefine('DWS_NO_VCL');
      Builder.AddDefine('RDTSC');
      Builder.AddDefine('RPC_SERWER');
      Builder.AddDefine('RPC_KLIENT');
      Builder.AddDefine('USE_EWID');
      Builder.AddDefine('USE_REAS');
      Builder.AddDefine('USE_NADZ');
      Builder.AddDefine('MON_ACTIONS');
      Builder.AddDefine('LARGE_ADDRESS');
      Builder.AddDefine('DELPHI_AST');

      try
        StringStream := TStringStream.Create;
        try
          StringStream.LoadFromFile(FilePath);
          // Wypełnić ścieżką do katalogu inc
          Builder.IncludeHandler := TIncludeHandler.Create('C:/[...]/inc');
          FileNameOnly := ChangeFileExt(ExtractFileName(FilePath), '');
          Builder.OnHandleString := OnHandleString;
          StringStream.Position := 0;

          SyntaxTree := Builder.Run(StringStream);
          try
            Xml := TSyntaxTreeWriter.ToXML(SyntaxTree, True);
            Json := DelphiASTXmlToJson(Xml, FileNameOnly);
            result := Json;
          finally
            SyntaxTree.Free;
          end;
        finally
          StringStream.Free;
        end;
      finally
        Builder.Free;
      end
    finally
      if UseStringInterning then
        StringPool.Free;
    end;
    sw.Stop;
end;

function TMainForm.XmlToJson(const XmlText: string): string;

  function XmlNodeToJson(Node: TDOMNode): TJSONData;
  var
    Obj: TJSONObject;
    Arr: TJSONArray;
    I: Integer;
    Child: TDOMNode;
  begin
    Obj := TJSONObject.Create;

    // unikalny klucz dla nazwy elementu
    Obj.Add('nodeName', Node.NodeName);

    // atrybuty XML
    if Node.Attributes <> nil then
      for I := 0 to Node.Attributes.Length - 1 do
        Obj.Add(Node.Attributes[I].NodeName, Node.Attributes[I].NodeValue);

    // dzieci
    Arr := TJSONArray.Create;
    Child := Node.FirstChild;
    while Child <> nil do
    begin
      if Child.NodeType = ELEMENT_NODE then
        Arr.Add(XmlNodeToJson(Child));
      Child := Child.NextSibling;
    end;

    if Arr.Count > 0 then
      Obj.Add('children', Arr)
    else
      Arr.Free;

    Result := Obj;
  end;

var
  Doc: TXMLDocument;
  Stream: TStringStream;
  Json: TJSONData;
begin
  Stream := TStringStream.Create(XmlText);
  try
    ReadXMLFile(Doc, Stream);
    try
      Json := XmlNodeToJson(Doc.DocumentElement);
      try
        Result := Json.FormatJSON;
      finally
        Json.Free;
      end;
    finally
      Doc.Free;
    end;
  finally
    Stream.Free;
  end;
end;

{ TIncludeHandler }

constructor TIncludeHandler.Create(const Path: string);
begin
  inherited Create;
  FPath := Path;
end;

function TIncludeHandler.GetIncludeFileContent(const ParentFileName, IncludeName: string;
  out Content: string; out FileName: string): Boolean;
var
  FileContent: TStringList;
begin
  FileContent := TStringList.Create;
  try
    if not FileExists(TPath.Combine(FPath, IncludeName)) then
    begin
      Result := False;
      Exit;
    end;

    FileContent.LoadFromFile(TPath.Combine(FPath, IncludeName));
    Content := FileContent.Text;
    FileName := TPath.Combine(FPath, IncludeName);

    Result := True;
  finally
    FileContent.Free;
  end;
end;

end.


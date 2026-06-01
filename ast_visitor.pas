unit ast_visitor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpjson,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Visitor;

type
  TAstJsonVisitor = class(TBaseASTVisitor)
  private
    FRoot: TJSONObject;
    FClasses: TJSONArray;
    FCurrentClass: TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Visit(Node: TUnitNode); override;
    procedure Visit(Node: TClassNode); override;
    procedure Visit(Node: TMethodNode); override;

    property Json: TJSONObject read FRoot;
  end;

implementation

constructor TAstJsonVisitor.Create;
begin
  FRoot := TJSONObject.Create;
  FClasses := TJSONArray.Create;
end;

destructor TAstJsonVisitor.Destroy;
begin
  FRoot.Free;
  inherited;
end;

procedure TAstJsonVisitor.Visit(Node: TUnitNode);
begin
  FRoot.Add('unit', Node.Name);
  FRoot.Add('classes', FClasses);
  inherited;
end;

procedure TAstJsonVisitor.Visit(Node: TClassNode);
var
  Inherits: string;
begin
  FCurrentClass := TJSONObject.Create;
  FCurrentClass.Add('name', Node.Name);

  if Assigned(Node.AncestorType) then
    Inherits := Node.AncestorType.Name
  else
    Inherits := '';

  FCurrentClass.Add('inherits', Inherits);
  FCurrentClass.Add('methods', TJSONArray.Create);

  FClasses.Add(FCurrentClass);
  inherited;
end;

procedure TAstJsonVisitor.Visit(Node: TMethodNode);
var
  MethodObj: TJSONObject;
  ParamsArr: TJSONArray;
  P: TParameterNode;
begin
  MethodObj := TJSONObject.Create;
  MethodObj.Add('name', Node.Name);
  MethodObj.Add('returnType', Node.ReturnType);
  MethodObj.Add('override', Node.IsOverride);
  MethodObj.Add('virtual', Node.IsVirtual);
  MethodObj.Add('reintroduce', Node.IsReintroduce);

  ParamsArr := TJSONArray.Create;

  for P in Node.Parameters do
  begin
    ParamsArr.Add(
      TJSONObject.Create([
        'name', P.Name,
        'type', P.TypeName,
        'modifier', P.Modifier.ToString
      ])
    );
  end;

  MethodObj.Add('parameters', ParamsArr);
  TJSONArray(FCurrentClass.Find('methods')).Add(MethodObj);
end;

end.


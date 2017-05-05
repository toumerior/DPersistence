unit uBancoDados;

interface

uses
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, Vcl.StdCtrls, FireDAC.Phys.IBBase;

type
  TBD = class
  private
    class var FConexao: TFDConnection;
    class procedure SetConexao(const Value: TFDConnection); static;
  public
    class property Conexao: TFDConnection read FConexao write SetConexao;
  end;

implementation

{ TBD }

class procedure TBD.SetConexao(const Value: TFDConnection);
begin
  FConexao := Value;
end;

end.

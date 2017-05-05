unit uAtribEntity;

interface

type
  TTipoLigacao = (Inner, Left, Nenhum);

type
  NomeTabela = class(TCustomAttribute)
  private
    FNome_Tabela: string;
  public
    constructor Create(nome_tabela: string);
    property Nome_Tabela: string read FNome_Tabela write FNome_Tabela;
  end;

  DadosColuna = class(TCustomAttribute)
  private
    FNome_Coluna: string;
    FChave_Primaria: Boolean;
    FSomente_Leitura: Boolean;
  public
    constructor Create(nome_coluna: string; chave_primaria: Boolean; somente_leitura: Boolean);
    property Nome_Coluna: string read FNome_Coluna write FNome_Coluna;
    property Chave_Primaria: Boolean read FChave_Primaria write FChave_Primaria;
    property Somente_Leitura: Boolean read FSomente_Leitura write FSomente_Leitura;
  end;

  ChaveEstrangeira = class(TCustomAttribute)
  private
    FApelido_Tabela_Estrangeira: string;
    FTipo_Ligacao: TTipoLigacao;
    FTabela_Estrangeira: string;
    FColuna_Estrangeira: string;
  public
    constructor Create(tabela_estrangeira: string; apelido_tab_estrangeira: string; coluna_estrangeira: string; tipo_ligacao: TTipoLigacao);
    property Tabela_Estrangeira: string read FTabela_Estrangeira write FTabela_Estrangeira;
    property Apelido_Tabela_Estrangeira: string read FApelido_Tabela_Estrangeira write FApelido_Tabela_Estrangeira;
    property Coluna_Estrangeira: string read FColuna_Estrangeira write FColuna_Estrangeira;
    property Tipo_Ligacao: TTipoLigacao read FTipo_Ligacao write FTipo_Ligacao;
  end;

implementation

{ ChaveEstrangeira }

constructor ChaveEstrangeira.Create(
  tabela_estrangeira: string;
  apelido_tab_estrangeira: string;
  coluna_estrangeira: string;
  tipo_ligacao: TTipoLigacao
);
begin
  FTabela_Estrangeira := tabela_estrangeira;
  FColuna_Estrangeira := coluna_estrangeira;
  FApelido_Tabela_Estrangeira := apelido_tab_estrangeira;
  FTipo_Ligacao := tipo_ligacao;
end;

{ NomeCampo }

constructor DadosColuna.Create(nome_coluna: string; chave_primaria: Boolean; somente_leitura: Boolean);
begin
  FNome_Coluna := nome_coluna;
  FChave_Primaria := chave_primaria;
  FSomente_Leitura := somente_leitura;
end;

{ NomeTabela }

constructor NomeTabela.Create(nome_tabela: string);
begin
  FNome_Tabela := nome_tabela;
end;

end.

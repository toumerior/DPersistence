unit uGenericDAO;

interface

uses
  RTTI, TypInfo, SysUtils, uAtribEntity, System.Generics.Collections, System.StrUtils, uTiposPrimitivos,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, Vcl.StdCtrls, FireDAC.Phys.IBBase, FireDAC.Dapt, uBancoDados;

type
  TGenericDAO = class(TObject)
  private
    FClass: TObject;

    function GetNomeTabela: string;
    function Clausula(var adicionou_where: Boolean): string;
    function strIgualdade(str_valor: string): string;
  public
    constructor Create; virtual; abstract;

    function Select: TObjectList<TObject>;
    function Insert: string;
    function Update: string;

    property Classe: TObject read FClass write FClass;
  end;

implementation

uses
  System.Classes;

const
  cIgualdade = ' = ';
  cIsNull    = ' is null ';

function TGenericDAO.GetNomeTabela: string;
var
  Contexto: TRttiContext;
  TypObj: TRttiType;
  Atributo: TCustomAttribute;

begin
  Contexto := TRttiContext.Create;
  TypObj := Contexto.GetType(FClass.ClassInfo);
  for Atributo in TypObj.GetAttributes do
  begin
    if Atributo is NomeTabela then
      Exit(NomeTabela(Atributo).Nome_Tabela);
  end;
end;

function TGenericDAO.Insert: string;
var
  Contexto: TRttiContext;
  TypObj: TRttiType;
  Prop: TRttiProperty;
  comando_insert, campos, valores: String;
  tipo_valor: string;
  Atributo: TCustomAttribute;

  valor: string;
  value_str: TString;
  value_int: TInteger;
  value_double: TDouble;
  value_date: TDate;

begin
  comando_insert := EmptyStr;
  campos := EmptyStr;
  valores := EmptyStr;

  comando_insert := 'insert into ' + GetNomeTabela;

  Contexto := TRttiContext.Create;
  TypObj := Contexto.GetType(FClass.ClassInfo);

  for Prop in TypObj.GetProperties do begin
    try
      case Prop.GetValue(FClass).Kind of
        tkClass: Break;

        tkRecord: begin
          if Prop.GetValue(Fclass).IsType(TypeInfo(TString)) then begin
            tipo_valor := 'TString';

            value_str := Prop.GetValue(FClass).AsType<TString>;

            if value_str.HasValue then
              valor := QuotedStr(value_str) + ', '
            else
              valor := 'null, ';
          end
          else if Prop.GetValue(Fclass).IsType(TypeInfo(TInteger)) then begin
            tipo_valor := 'TInteger';

            value_int := Prop.GetValue(FClass).AsType<TInteger>;

            if value_int.HasValue then
              valor := IntToStr(value_int) + ', '
            else
              valor := 'null, ';
          end
          else if Prop.GetValue(Fclass).IsType(TypeInfo(TDouble)) then begin
            tipo_valor := 'TDouble';

            value_double := Prop.GetValue(FClass).AsType<TDouble>;

            if value_double.HasValue then
              valor := FloatToStr(value_double) + ', '
            else
              valor := 'null, ';
          end
          else if Prop.GetValue(Fclass).IsType(TypeInfo(TDate)) then begin
            tipo_valor := 'TDate';

            value_date := Prop.GetValue(FClass).AsType<TDate>;

            if value_date.HasValue then
              valor := DateTimeToStr(value_date) + ', '
            else
              valor := 'null, ';
          end
        end;
      end;
    except
      on e: Exception do
        raise Exception.Create('O valor informado (' + valor + ') na propriedade "' + Prop.Name + '" no objeto ' + FClass.ClassName + ' não é compátivel com o tipo definido na classe (' + tipo_valor + ')!');
    end;

    for Atributo in Prop.GetAttributes do begin
      if Atributo is DadosColuna then begin
        if DadosColuna(Atributo).Somente_Leitura then
          Break;

        campos := campos + DadosColuna(Atributo).Nome_Coluna + ', ';
        valores := valores + valor;
        Break;
      end;

      if Atributo is ChaveEstrangeira then
        Continue;
    end;
  end;

  campos := Copy(campos, 1, Length(campos) - 2);
  valores := Copy(valores, 1, Length(valores) - 2);
  comando_insert := comando_insert + ' ( ' + sLineBreak + campos + sLineBreak + ' )  values ( ' + sLineBreak + valores + sLineBreak + ' )';

  try
    //Executar SQL
    Result := comando_insert;
  except
    on e: Exception do
    begin
      raise E.Create('Erro: ' + e.Message);
    end;
  end;
end;

function TGenericDAO.Clausula(var adicionou_where: Boolean): string;
begin
  if adicionou_where then
    Result := ' and '
  else begin
    adicionou_where := True;
    Result := ' where ';
  end;
end;

function TGenericDAO.strIgualdade(str_valor: string): string;
begin
  Result := IfThen(str_valor <> ' is null ', ' = ');
end;

function TGenericDAO.Select: TObjectList<TObject>;
var
  contexto: TRttiContext;
  type_obj: TRttiType;
  prop: TRttiProperty;
  atributo: TCustomAttribute;

  script_select: TStringList;
  script_ligacoes: TStringList;
  str_valor: string;
  str_condicaoWhere: string;
  str_campos: string;
  adicionou_where: Boolean;

  apelido_tabelas: TDictionary<string, string>;
  apelido_tab_estrangeira: string;
  tabela_estrangeira: string;
  tabela_principal: string;
  apelido_tab_principal: string;
  str: string;
  tipo_valor: string;
  coluna: string;

  i: Integer;

  value_str: TString;
  value_int: TInteger;
  value_double: TDouble;
  value_date: TDate;

  filtrar_campo: Boolean;
  continuar_loop: Boolean;

  qry: TFDQuery;

  teste: TObject;

begin
  script_ligacoes := TStringList.Create;
  str_valor := EmptyStr;
  str_condicaoWhere := EmptyStr;
  str_campos := EmptyStr;
  adicionou_where := False;
  str := EmptyStr;

  tabela_principal := GetNomeTabela;
  apelido_tab_principal := Copy(tabela_principal, 1, 3);
  apelido_tabelas := TDictionary<string, string>.Create;
  apelido_tabelas.Add(tabela_principal, apelido_tab_principal);

  contexto := TRttiContext.Create;
  type_obj := contexto.GetType(FClass.ClassInfo);

  //Buscando as propertys do objeto
  for prop in type_obj.GetProperties do begin
    filtrar_campo := True;

    //Verificando se existe valor
    if not prop.GetValue(FClass).IsEmpty then
    begin
      str_valor := EmptyStr;

      try
        case prop.GetValue(FClass).Kind of
          //Tive que fazer isso porque o RTTI percorre também as propertys da classe pai
          tkClass: Continue;

          tkRecord: begin
            if prop.GetValue(Fclass).IsType(TypeInfo(TString)) then begin
              tipo_valor := 'TString';

              value_str := prop.GetValue(FClass).AsType<TString>;

              if value_str.HasValue then
                str_valor := QuotedStr(value_str)
              else if value_str.Value_Null then
                str_valor := ' is null '
              else
               filtrar_campo := False;
            end
            else if prop.GetValue(Fclass).IsType(TypeInfo(TInteger)) then begin
              tipo_valor := 'TInteger';

              value_int := prop.GetValue(FClass).AsType<TInteger>;

              if value_int.HasValue then
                str_valor := IntToStr(value_int)
              else if value_int.Value_Null then
                str_valor := ' is null '
              else
                filtrar_campo := False;
            end
            else if prop.GetValue(Fclass).IsType(TypeInfo(TDouble)) then begin
              tipo_valor := 'TDouble';

              value_double := prop.GetValue(FClass).AsType<TDouble>;

              if value_double.HasValue then
                str_valor := FloatToStr(value_double)
              else if value_double.Value_Null then
                str_valor := ' is null '
              else
                filtrar_campo := False;
            end
            else if prop.GetValue(Fclass).IsType(TypeInfo(TDate)) then begin
              tipo_valor := 'TDate';

              value_date := prop.GetValue(FClass).AsType<TDate>;

              if value_date.HasValue then
                str_valor := DateTimeToStr(value_date)
              else if value_date.Value_Null then
                str_valor := ' is null '
              else
                filtrar_campo := False;
            end
          end;
        end;
      except
        on e: Exception do
          raise Exception.Create('O valor informado (' + str_valor + ') na propriedade "' + prop.Name + '" no objeto ' + FClass.ClassName + ' não é compátivel com o tipo definido na classe (' + tipo_valor + ')!');
      end;
    end;

    apelido_tab_estrangeira := EmptyStr;
    coluna := EmptyStr;

    for atributo in prop.GetAttributes do begin
      if atributo is DadosColuna then begin
        if coluna = EmptyStr then
          coluna := DadosColuna(atributo).Nome_Coluna;

        Continue;
      end
      else if atributo is ChaveEstrangeira then begin
        apelido_tab_estrangeira := ChaveEstrangeira(atributo).Apelido_Tabela_Estrangeira;

        if apelido_tab_estrangeira = EmptyStr then
          Continue;

        //Verificando se o campo em questão faz referência a uma coluna de outra tabela
        if ChaveEstrangeira(atributo).Coluna_Estrangeira <> EmptyStr then begin
          tabela_estrangeira := ChaveEstrangeira(atributo).Tabela_Estrangeira;

          //Verificando se já foi adicionado essa tabela estrangeira no inner
          if apelido_tabelas.ContainsKey(apelido_tab_estrangeira) then begin
            //Lembra que quando não existe a ligação com a tabela ainda, adicionamos uma linha em branco? Pois é, agora vamos adicionar o "AND" nela.
            i := script_ligacoes.IndexOf(apelido_tab_estrangeira) + 2;

            //Porém, pode ser um inner com 3 colunas ou mais. Por isso vamos procurar a próxima linha em branco antes de adicionar
            while script_ligacoes[i] <> EmptyStr do
              Inc(i);

            //Lembra que quando não existe a ligação com a tabela ainda, adicionamos uma linha em branco? Pois é, agora vamos adicionar o "AND" nela.
            script_ligacoes.Insert(i, 'and ' + apelido_tab_principal + '.' + ChaveEstrangeira(atributo).Coluna_Estrangeira + ' = ' + apelido_tab_estrangeira +  '.' + ChaveEstrangeira(atributo).Coluna_Estrangeira);
          end
          else begin
            apelido_tabelas.Add(apelido_tab_estrangeira, str);

            //Montando a ligação, pois se entrou aqui, significa que ainda não existia o inner com essa tabela...
            script_ligacoes.Add(IfThen(ChaveEstrangeira(atributo).Tipo_Ligacao = Inner, 'inner ', 'left ') +  ' join ' + tabela_estrangeira + ' ' + apelido_tab_estrangeira);
            script_ligacoes.Add('on ' + apelido_tab_principal + '.' + ChaveEstrangeira(atributo).Coluna_Estrangeira + ' = ' + apelido_tab_estrangeira +  '.' + ChaveEstrangeira(atributo).Coluna_Estrangeira);

            //Adicionando essa linha vazia, pois a mesma irá servir para quando for necessário adicionar mais um filtro no inner dessa tabela...
            script_ligacoes.Add(EmptyStr);
          end;

          coluna := ChaveEstrangeira(atributo).Coluna_Estrangeira;
        end;
      end;

    end; //For atributo

    str_campos := str_campos + '  ' + IfThen(apelido_tab_estrangeira <> EmptyStr, apelido_tab_estrangeira, apelido_tab_principal) + '.' + coluna + ', ' + sLineBreak;

    //Essa variável é marcada com True se existir algum valor na propriedade percorrida.
    if filtrar_campo then
      str_condicaoWhere := str_condicaoWhere + Clausula(adicionou_where) + IfThen(apelido_tab_estrangeira = EmptyStr, apelido_tab_principal, apelido_tab_estrangeira) + '.' + coluna + strIgualdade(str_valor) + str_valor + sLineBreak;
  end;

  str_campos := Trim(str_campos);
  str_campos := Copy(str_campos, 0, Length(str_campos) - 1);
  str_condicaoWhere := Trim(str_condicaoWhere);

  script_select := TStringList.Create;
  script_select.Add('select');
  script_select.Add('  ' + str_campos);
  script_select.Add('from ');
  script_select.Add('  ' + tabela_principal + ' ' + apelido_tab_principal);
  script_select.Add(EmptyStr);

  if script_ligacoes.GetText <> EmptyStr then
    script_select.Add(script_ligacoes.GetText);

  script_select.Add(str_condicaoWhere);

  try
    //Executar SQL
    Result := script_select.GetText;

    //Executando o SQL
    qry := TFDQuery.Create(nil);
    qry.Connection := TBD.Conexao;
    qry.Open(script_select.GetText);

    if not qry.IsEmpty then begin
      Result := TObjectList<TObject>.Create;

      qry.First;
      while not qry.EoF do begin
        FClass := FClass.NewInstance;

        for i := 0 to qry.FieldCount - 1 do begin //Loop de coluna por coluna para localizar o campo no objeto
          for prop in type_obj.GetProperties do begin
            continuar_loop := True;

            for atributo in prop.GetAttributes do begin
              if atributo is DadosColuna then begin
                if DadosColuna(atributo).Nome_Coluna = qry.Fields[i].FieldName then
                begin
                  if prop.GetValue(Fclass).IsType(TypeInfo(TString)) then
                    prop.SetValue(FClass, TValue.From(TString(qry.Fields[i].AsString)))
                  else if prop.GetValue(Fclass).IsType(TypeInfo(TInteger)) then
                    prop.SetValue(FClass, TValue.From(TInteger(qry.Fields[i].AsInteger)))
                  else if prop.GetValue(Fclass).IsType(TypeInfo(TDouble)) then
                    prop.SetValue(FClass, TValue.From(TDouble(qry.Fields[i].AsFloat)))
                  else if prop.GetValue(Fclass).IsType(TypeInfo(TDate)) then
                    prop.SetValue(FClass, TValue.From(qry.Fields[i].AsDateTime));

                  continuar_loop := False;
                  Break;
                end;
              end;
            end;

            if not continuar_loop then
              Break;
          end;
        end;


        Result.Add(FClass);
        qry.Next;
      end;
    end;
  except
    on e: Exception do
    begin
      raise E.Create('Erro: ' + e.Message);
    end;
  end;

  script_select.Free;
end;

function TGenericDAO.Update: string;
var
  Contexto: TRttiContext;
  TypObj: TRttiType;
  Prop: TRttiProperty;
  comando_update: String;
  tipo_valor: string;
  Atributo: TCustomAttribute;
  colunas: string;
  comando_where: string;
  adicionou_where: Boolean;

  valor: string;
  value_str: TString;
  value_int: TInteger;
  value_double: TDouble;
  value_date: TDate;

  function Clausula: string;
  begin
    if adicionou_where then
      Result := 'and '
    else begin
      adicionou_where := True;
      Result := 'where ';
    end;
  end;
begin
  comando_update := EmptyStr;
  comando_where := EmptyStr;
  tipo_valor := EmptyStr;
  colunas := EmptyStr;
  valor := EmptyStr;
  adicionou_where := False;

  Contexto := TRttiContext.Create;
  TypObj := Contexto.GetType(FClass.ClassInfo);

  for Prop in TypObj.GetProperties do begin
    try
      case Prop.GetValue(FClass).Kind of
        tkClass: Break;

        tkRecord: begin
          if Prop.GetValue(Fclass).IsType(TypeInfo(TString)) then begin
            tipo_valor := 'TString';

            value_str := Prop.GetValue(FClass).AsType<TString>;

            if value_str.HasValue then
              valor := QuotedStr(value_str) + ', '
            else if value_str.Value_Null then
              valor := 'null, '
            else
             valor := EmptyStr;
          end
          else if Prop.GetValue(Fclass).IsType(TypeInfo(TInteger)) then begin
            tipo_valor := 'TInteger';

            value_int := Prop.GetValue(FClass).AsType<TInteger>;

            if value_int.HasValue then
              valor := IntToStr(value_int) + ', '
            else if value_int.Value_Null then
              valor := 'null, '
            else
              valor := EmptyStr;
          end
          else if Prop.GetValue(Fclass).IsType(TypeInfo(TDouble)) then begin
            tipo_valor := 'TDouble';

            value_double := Prop.GetValue(FClass).AsType<TDouble>;

            if value_double.HasValue then
              valor := FloatToStr(value_double) + ', '
            else if value_double.Value_Null then
              valor := 'null, '
            else
              valor := EmptyStr;
          end
          else if Prop.GetValue(Fclass).IsType(TypeInfo(TDate)) then begin
            tipo_valor := 'TDate';

            value_date := Prop.GetValue(FClass).AsType<TDate>;

            if value_date.HasValue then
              valor := DateToStr(value_date) + ', '
            else if value_date.Value_Null then
              valor := 'null, '
            else
              valor := EmptyStr;
          end
        end;
      end;
    except
      on e: Exception do
        raise Exception.Create('O valor informado (' + valor + ') na propriedade "' + Prop.Name + '" no objeto ' + FClass.ClassName + ' não é compátivel com o tipo definido na classe (' + tipo_valor + ')!');
    end;

    if valor = EmptyStr then
      Continue;

    for Atributo in Prop.GetAttributes do begin
      if Atributo is DadosColuna then begin
        if DadosColuna(Atributo).Somente_Leitura then
          Break;

        if DadosColuna(Atributo).Chave_Primaria then begin
          valor := Copy(valor, 1, Length(valor) - 2);
          comando_where := comando_where + Clausula + DadosColuna(Atributo).Nome_Coluna + ' = ' + valor + sLineBreak;
        end
        else
          colunas := colunas + '  ' + DadosColuna(Atributo).Nome_Coluna + ' = ' + valor + sLineBreak;
      end;
      Break;
    end;
  end;
  colunas := Trim(colunas);
  colunas := Copy(colunas, 1, Length(colunas) - 1);

  if comando_where = EmptyStr then begin
    raise Exception.Create('Não pode ser montado um update sem informar a clausula WHERE');
  end;

  comando_update :=
    'update ' + GetNomeTabela + ' set ' + sLineBreak +
    '  ' + colunas + sLineBreak +
    comando_where;

  try
    //Executar SQL
    Result := comando_update;
  except
    on e: Exception do
    begin
      raise E.Create('Erro: ' + e.Message);
    end;
  end;
end;

end.

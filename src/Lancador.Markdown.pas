// Eduardo - 07/09/2024
unit Lancador.Markdown;

interface

{$SCOPEDENUMS ON}

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShellAPI,
  {$ENDIF MSWINDOWS}
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.RegularExpressions,
  FMX.Objects,
  FMX.Types,
  FMX.TextLayout,
  FMX.Graphics,
  FMX.Platform,
  FMX.Clipboard,
  FMX.Controls;

type
  TMarkKind = (Header, Bold, Italic, Underline, List, Code, MDHiperlink, Hiperlink);

  TMarkItem = record
  public
    Kind: TMarkKind;
    Font: TFont;
    Range: TTextRange;
    Attribute: TTextAttribute;
    Value: String;
  end;

  TText = class(FMX.Objects.TText)
  private
    Itens: TArray<TMarkItem>;
    FIsMarkdown: Boolean;
    FOriginalFontSize: Single;
    FOriginalOpacity: Single;
    function GetNewText: String;
    procedure SetNewText(const Value: String);
    function RemoveMarkdown(const OriginalText: String): String;
    procedure SetMarkdown(const Value: Boolean);
  protected
    procedure Click; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property IsMarkdown: Boolean read FIsMarkdown write SetMarkdown;
    property Text: String read GetNewText write SetNewText;
  end;

implementation

{ TText }

constructor TText.Create(AOwner: TComponent);
begin
  inherited;
  FOriginalFontSize := Font.Size;
  FOriginalOpacity := Self.Opacity;
  FIsMarkdown := False;
end;

destructor TText.Destroy;
begin
  for var Item in Itens do
    FreeAndNil(Item.Font);
  Itens := [];
  inherited;
end;

function TText.GetNewText: string;
begin
  Result := inherited Text;
end;

procedure TText.SetMarkdown(const Value: Boolean);
begin
  FIsMarkdown := Value;
  if Value then
  begin
    Font.Family := 'Helvetica';
    Font.Size := 12;
    Self.Opacity := 0.75;
  end
  else
  begin
    Font.Size := FOriginalFontSize;
    Self.Opacity := FOriginalOpacity;
  end;
  Text := Text;
end;

procedure TText.SetNewText(const Value: string);
const
  FontSizes: TArray<Single> = [24, 18, 14.04, 12, 9.96, 8.04];
  BoldPattern = '(?<!\*)\*\*(?!\*)(.*?)\*\*(?!\*)';
  ItalicPattern = '(?<!\*)\*(?!\*)(.*?)\*(?!\*)';
  UnderlinePattern = '(?<!_)__(?!_)(.*?)__(?!_)';
  ListPattern = '(^\*[^*].+)';
  CodePattern = '(`.+`)';
  MDLinkPattern = '\[.+?\]\(.+?\)';
  LinkPattern = '(?<!\()(http|ftp|https):\/\/([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])(?<!\))';
var
  I: Integer;
  Item: TMarkItem;
  Matches: TMatchCollection;
  Match: TMatch;
  Temp: String;
begin
  Temp := Value.Replace('&', '&&');

  // Limpa
  for var Mark in Itens do
    FreeAndNil(Mark.Font);
  Itens := [];

  if not IsMarkdown then
  begin
    inherited Text := Temp;
    Exit;
  end;

  // Títulos
  for I := Low(FontSizes) to High(FontSizes) do
  begin
    Matches := TRegEx.Matches(Temp, '^#{'+ Succ(I).ToString +'}[^#].+', [roMultiLine]);
    for Match in Matches do
    begin
      Item := Default(TMarkItem);
      Item.Kind := TMarkKind.Header;
      Item.Font := TFont.Create;
      Item.Font.Assign(Self.Font);
      Item.Font.Size := FontSizes[I];
      Item.Font.Style := [TFontStyle.fsBold];
      Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
      Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 0).ToAlphaColor);
      Item.Value := Match.Value;
      Itens := Itens + [Item];
    end;
  end;

  // Negrito
  Matches := TRegEx.Matches(Temp, BoldPattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.Bold;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Style := [TFontStyle.fsBold];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 0).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  // Itálico
  Matches := TRegEx.Matches(Temp, ItalicPattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.Italic;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Style := [TFontStyle.fsItalic];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 0).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  // Sublinhado
  Matches := TRegEx.Matches(Temp, UnderlinePattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.Underline;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Style := [TFontStyle.fsUnderline];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 0).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  // Lista
  Matches := TRegEx.Matches(Temp, ListPattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.List;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Style := [];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 0).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  // Codigo
  Matches := TRegEx.Matches(Temp, CodePattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.Code;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Family := 'Cascadia Mono';
    Item.Font.Style := [];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 0).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  // MD Hiperlink
  Matches := TRegEx.Matches(Temp, MDLinkPattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.MDHiperlink;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Style := [TFontStyle.fsUnderline];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 238 / 255).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  // Hiperlink
  Matches := TRegEx.Matches(Temp, LinkPattern, [roMultiLine]);
  for Match in Matches do
  begin
    Item := Default(TMarkItem);
    Item.Kind := TMarkKind.Hiperlink;
    Item.Font := TFont.Create;
    Item.Font.Assign(Self.Font);
    Item.Font.Style := [TFontStyle.fsUnderline];
    Item.Range := TTextRange.Create(Match.Index - 1, Match.Length);
    Item.Attribute := TTextAttribute.Create(Item.Font, TAlphaColorF.Create(0, 0, 238 / 255).ToAlphaColor);
    Item.Value := Match.Value;
    Itens := Itens + [Item];
  end;

  inherited Text := RemoveMarkdown(Temp);
end;

function TText.RemoveMarkdown(const OriginalText: String): String;
var
  I: Integer;
  Deslocamento: Integer;
  TamanhoAnterior: Integer;
begin
  Result := OriginalText;
  Deslocamento := 0;

  // Ordenar o array de formatações pelo índice de forma decrescente para ajuste correto
  TArray.Sort<TMarkItem>(Itens, TComparer<TMarkItem>.Construct(
    function(const Left, Right: TMarkItem): Integer
    begin
      Result := Left.Range.Pos - Right.Range.Pos;
    end
  ));

  // Remover formatação do markdown e ajustar o texto
  for I := Low(Itens) to High(Itens) do
  begin
    TamanhoAnterior := Length(Result);
    case Itens[I].Kind of
      TMarkKind.Header:      Result := Result.Replace(Itens[I].Value, Itens[I].Value.Replace('#', EmptyStr).Trim);
      TMarkKind.Bold:        Result := Result.Replace(Itens[I].Value, Itens[I].Value.Replace('**', EmptyStr));
      TMarkKind.Italic:      Result := Result.Replace(Itens[I].Value, Itens[I].Value.Replace('*', EmptyStr));
      TMarkKind.Underline:   Result := Result.Replace(Itens[I].Value, Itens[I].Value.Replace('_', EmptyStr));
      TMarkKind.List:        Result := Result.Replace(Itens[I].Value, Itens[I].Value.Replace('*', '    ●'));
      TMarkKind.Code:        Result := Result.Replace(Itens[I].Value, Itens[I].Value.Replace('`', EmptyStr));
      TMarkKind.MDHiperlink: Result := Result.Replace(Itens[I].Value, TRegEx.Replace(Itens[I].Value, '\(.+?\)', EmptyStr, [roMultiLine]).TrimLeft(['[']).TrimRight([']']));
      TMarkKind.Hiperlink:;
    end;

    // Ajusta o item atual
    Itens[I].Range.Pos := Itens[I].Range.Pos - Deslocamento;

    // Atualiza o tamanho
    Itens[I].Range.Length := Itens[I].Range.Length - (TamanhoAnterior - Length(Result));

    // Atualizar o deslocamento para os próximos ajustes
    Deslocamento := Deslocamento + (TamanhoAnterior - Length(Result));

    // Adiciona ao layout
    Layout.AddAttribute(Itens[I].Range, Itens[I].Attribute);
  end;
end;

procedure TText.Click;
var
  srv: IFMXMouseService;
  P: TPointF;
  CaretPos: Integer;
  I: Integer;
  sLink: String;
begin
  inherited;

  if not TPlatformServices.Current.SupportsPlatformService(IFMXMouseService, IInterface(srv)) then
    Exit;

  P := Self.ScreenToLocal(srv.GetMousePos);
  CaretPos := Layout.PositionAtPoint(TPointF.Create(P.X, P.Y));

  for I := Low(Itens) to High(Itens) do
  begin
    if (Itens[I].Kind in [TMarkKind.MDHiperlink, TMarkKind.Hiperlink]) and Itens[I].Range.InRange(CaretPos) then
    begin
      case Itens[I].Kind of
        TMarkKind.MDHiperlink: sLink := TRegEx.Replace(Itens[I].Value, '[\[].+[?\]]', EmptyStr).TrimLeft(['(']).TrimRight([')']);
        TMarkKind.Hiperlink:   sLink := Copy(Text, Succ(Itens[I].Range.Pos), Itens[I].Range.Length);
      end;

      Self.Canvas.BeginScene;
      Self.Layout.BeginUpdate;
      try
        Itens[I].Attribute.Color := TAlphaColorF.Create(85 / 255, 26 / 255, 139 / 255).ToAlphaColor;
        Self.Layout.AddAttribute(Itens[I].Range, Itens[I].Attribute);
      finally
        Self.Layout.EndUpdate;
        Self.Canvas.EndScene;
      end;

      Self.Repaint;
      Break;
    end;
  end;

  if not sLink.IsEmpty then
  begin
    {$IFDEF MSWINDOWS}
    ShellExecute(0, 'open', PChar(sLink), '', '', SW_SHOWNORMAL);
    {$ENDIF MSWINDOWS}
    {$IFDEF POSIX}
    _system(PAnsiChar('open '+ AnsiString(sLink)));
    {$ENDIF POSIX}
  end;
end;

procedure TText.MouseMove(Shift: TShiftState; X, Y: Single);
var
  CaretPos: Integer;
  I: Integer;
  cr: TCursor;
begin
  inherited;

  cr := crDefault;
  try
    if Length(Itens) = 0 then
      Exit;

    CaretPos := Layout.PositionAtPoint(TPointF.Create(X, Y));
    for I := Low(Itens) to High(Itens) do
    begin
      if not (Itens[I].Kind in [TMarkKind.MDHiperlink, TMarkKind.Hiperlink]) then
        Continue;

      if Itens[I].Range.InRange(CaretPos) then
      begin
        cr := crHandPoint;
        Break;
      end;
    end;
  finally
    if Self.Cursor <> cr then
      Self.Cursor := cr;
  end;
end;

end.

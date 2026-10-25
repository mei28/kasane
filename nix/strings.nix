# Compiles bundle/Localizable.xcstrings the way `xcrun xcstringstool compile` does, for a catalog
# whose English keys each have one translated Japanese string. Anything else stops evaluation, so
# the app never ships with a string this compiler dropped or misread.
{ lib }:
let
  # One problem for each attribute of `attrs` not named in `known`.
  unsupported =
    where: known: attrs:
    map (name: "${where}: unsupported ${name}") (lib.subtractLists known (lib.attrNames attrs));

  entryProblems =
    key: entry:
    let
      where = builtins.toJSON key;
      ja = entry.localizations.ja;
    in
    unsupported where [ "localizations" ] entry
    ++ (
      if !(entry ? localizations.ja) then
        [ "${where}: no ja localization" ]
      else
        unsupported "${where} localizations" [ "ja" ] entry.localizations
        ++ unsupported "${where} ja" [ "stringUnit" ] ja
        ++ (
          if !(ja ? stringUnit) then
            [ "${where} ja: no stringUnit" ]
          else
            lib.optional (
              ja.stringUnit.state != "translated"
            ) "${where} ja: state ${ja.stringUnit.state}, not translated"
        )
    );

  # Every reason the catalog cannot be compiled. Empty when it can.
  problems =
    catalog:
    unsupported "catalog" [ "sourceLanguage" "strings" "version" ] catalog
    ++ lib.optional (
      catalog.sourceLanguage != "en"
    ) "catalog: sourceLanguage ${catalog.sourceLanguage}, not en"
    ++ lib.optional (catalog.version != "1.0") "catalog: version ${catalog.version}, not 1.0"
    ++ lib.concatLists (lib.mapAttrsToList entryProblems catalog.strings);

  # The Japanese string for each English key.
  translations =
    catalog: lib.mapAttrs (_: entry: entry.localizations.ja.stringUnit.value) catalog.strings;
in
{
  inherit problems translations;

  # ja.lproj/Localizable.strings: an XML property list from each English key to its Japanese string.
  toStrings =
    catalog:
    let
      found = problems catalog;
    in
    if found != [ ] then
      throw "bundle/Localizable.xcstrings cannot be compiled:\n${lib.concatLines found}"
    else
      lib.generators.toPlist { escape = true; } (translations catalog);
}

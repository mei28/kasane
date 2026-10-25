# Tests for nix/strings.nix. `just test-nix` runs them.
{ pkgs, strings }:
let
  inherit (pkgs) lib;

  translated = value: {
    localizations.ja.stringUnit = {
      state = "translated";
      inherit value;
    };
  };
  catalog = entries: {
    sourceLanguage = "en";
    version = "1.0";
    strings = entries;
  };

  failures = lib.runTests {
    testTranslatedEntryHasNoProblems = {
      expr = strings.problems (catalog {
        "Add…" = translated "追加…";
      });
      expected = [ ];
    };
    testTranslationsMapEnglishKeysToJapanese = {
      expr = strings.translations (catalog {
        "Add…" = translated "追加…";
        "Remove" = translated "削除";
      });
      expected = {
        "Add…" = "追加…";
        "Remove" = "削除";
      };
    };
    # Xcode writes a string nobody has translated yet as an empty entry.
    testUntranslatedEntry = {
      expr = strings.problems (catalog {
        "Add…" = { };
      });
      expected = [ ''"Add…": no ja localization'' ];
    };
    testAnotherLanguage = {
      expr = strings.problems (catalog {
        "Add…" = lib.recursiveUpdate (translated "追加…") {
          localizations.fr.stringUnit = {
            state = "translated";
            value = "Ajouter…";
          };
        };
      });
      expected = [ ''"Add…" localizations: unsupported fr'' ];
    };
    # A plural takes variations in place of a stringUnit.
    testPluralVariations = {
      expr = strings.problems (catalog {
        "%lld taps".localizations.ja.variations.plural.other.stringUnit = {
          state = "translated";
          value = "%lld 回";
        };
      });
      expected = [
        ''"%lld taps" ja: unsupported variations''
        ''"%lld taps" ja: no stringUnit''
      ];
    };
    testSubstitutions = {
      expr = strings.problems (catalog {
        "Tap %#@taps@" = lib.recursiveUpdate (translated "%#@taps@ 回押す") {
          localizations.ja.substitutions.taps.formatSpecifier = "lld";
        };
      });
      expected = [ ''"Tap %#@taps@" ja: unsupported substitutions'' ];
    };
    testStringNeedingReview = {
      expr = strings.problems (catalog {
        "Add…" = lib.recursiveUpdate (translated "追加…") {
          localizations.ja.stringUnit.state = "needs_review";
        };
      });
      expected = [ ''"Add…" ja: state needs_review, not translated'' ];
    };
    testEntryComment = {
      expr = strings.problems (catalog {
        "Add…" = translated "追加…" // {
          comment = "The button that records a trigger";
        };
      });
      expected = [ ''"Add…": unsupported comment'' ];
    };
    testSourceLanguageOtherThanEnglish = {
      expr = strings.problems (catalog { } // { sourceLanguage = "ja"; });
      expected = [ "catalog: sourceLanguage ja, not en" ];
    };
    testAnotherCatalogVersion = {
      expr = strings.problems (catalog { } // { version = "1.1"; });
      expected = [ "catalog: version 1.1, not 1.0" ];
    };
    testUnknownCatalogKey = {
      expr = strings.problems (catalog { } // { generatedBy = "Xcode 27"; });
      expected = [ "catalog: unsupported generatedBy" ];
    };
    testProblemsOfEveryEntry = {
      expr = strings.problems (catalog {
        "Add…" = { };
        "Remove" = { };
      });
      expected = [
        ''"Add…": no ja localization''
        ''"Remove": no ja localization''
      ];
    };
    testToStringsRefusesACatalogWithProblems = {
      expr =
        (builtins.tryEval (
          strings.toStrings (catalog {
            "Add…" = { };
          })
        )).success;
      expected = false;
    };
    # `just check-strings` compares the whole output with xcstringstool's.
    testToStringsEscapesXML =
      let
        compiled = strings.toStrings (catalog {
          "Fn & <Shift>" = translated "fn と <Shift>";
        });
      in
      {
        expr = {
          key = lib.hasInfix "<key>Fn &amp; &lt;Shift&gt;</key>" compiled;
          string = lib.hasInfix "<string>fn と &lt;Shift&gt;</string>" compiled;
        };
        expected = {
          key = true;
          string = true;
        };
      };
  };
in
if failures == [ ] then
  pkgs.runCommand "strings-tests" { } "touch $out"
else
  throw "nix/strings.nix tests failed:\n${lib.generators.toPretty { } failures}"

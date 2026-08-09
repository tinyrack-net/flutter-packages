import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/ligature_font.dart';

void main() {
  final cases = _loadCases();
  group('addon-ligatures - index', () {
    group('findLigatures', () {
      test("Fira Code: 'abc'", () {
        final value = cases[0];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '.='", () {
        final value = cases[1];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '..='", () {
        final value = cases[2];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '.-'", () {
        final value = cases[3];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: ':='", () {
        final value = cases[4];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=:='", () {
        final value = cases[5];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=!='", () {
        final value = cases[6];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '__'", () {
        final value = cases[7];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=='", () {
        final value = cases[8];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '!='", () {
        final value = cases[9];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '==='", () {
        final value = cases[10];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '!=='", () {
        final value = cases[11];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=/='", () {
        final value = cases[12];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<-<'", () {
        final value = cases[13];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<<-'", () {
        final value = cases[14];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<--'", () {
        final value = cases[15];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<-'", () {
        final value = cases[16];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<->'", () {
        final value = cases[17];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '->'", () {
        final value = cases[18];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '-->'", () {
        final value = cases[19];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '->>'", () {
        final value = cases[20];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>->'", () {
        final value = cases[21];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<=<'", () {
        final value = cases[22];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<<='", () {
        final value = cases[23];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<=='", () {
        final value = cases[24];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<=>'", () {
        final value = cases[25];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=>'", () {
        final value = cases[26];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '==>'", () {
        final value = cases[27];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=>>'", () {
        final value = cases[28];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>=>'", () {
        final value = cases[29];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>>='", () {
        final value = cases[30];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>>-'", () {
        final value = cases[31];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>-'", () {
        final value = cases[32];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<~>'", () {
        final value = cases[33];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '-<'", () {
        final value = cases[34];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '-<<'", () {
        final value = cases[35];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '=<<'", () {
        final value = cases[36];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<~~'", () {
        final value = cases[37];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<~'", () {
        final value = cases[38];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '~~'", () {
        final value = cases[39];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '~>'", () {
        final value = cases[40];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '~~>'", () {
        final value = cases[41];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<<<'", () {
        final value = cases[42];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<<'", () {
        final value = cases[43];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<='", () {
        final value = cases[44];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<>'", () {
        final value = cases[45];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>='", () {
        final value = cases[46];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>>'", () {
        final value = cases[47];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '>>>'", () {
        final value = cases[48];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '{.'", () {
        final value = cases[49];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '{|'", () {
        final value = cases[50];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '[|'", () {
        final value = cases[51];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<:'", () {
        final value = cases[52];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: ':>'", () {
        final value = cases[53];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '|]'", () {
        final value = cases[54];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '|}'", () {
        final value = cases[55];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '.}'", () {
        final value = cases[56];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<|||'", () {
        final value = cases[57];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<||'", () {
        final value = cases[58];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<|'", () {
        final value = cases[59];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<|>'", () {
        final value = cases[60];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '|>'", () {
        final value = cases[61];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '||>'", () {
        final value = cases[62];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '|||>'", () {
        final value = cases[63];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test(r"Fira Code: '<$'", () {
        final value = cases[64];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test(r"Fira Code: '<$>'", () {
        final value = cases[65];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test(r"Fira Code: '$>'", () {
        final value = cases[66];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<+'", () {
        final value = cases[67];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<+>'", () {
        final value = cases[68];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '+>'", () {
        final value = cases[69];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<*'", () {
        final value = cases[70];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<*>'", () {
        final value = cases[71];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '*>'", () {
        final value = cases[72];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '/*'", () {
        final value = cases[73];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '*/'", () {
        final value = cases[74];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '///'", () {
        final value = cases[75];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '//'", () {
        final value = cases[76];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '</'", () {
        final value = cases[77];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '<!--'", () {
        final value = cases[78];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '</>'", () {
        final value = cases[79];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '/>'", () {
        final value = cases[80];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '0xff'", () {
        final value = cases[81];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '10x10'", () {
        final value = cases[82];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '9:45'", () {
        final value = cases[83];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '[:]'", () {
        final value = cases[84];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: ';;'", () {
        final value = cases[85];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '::'", () {
        final value = cases[86];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: ':::'", () {
        final value = cases[87];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '..'", () {
        final value = cases[88];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '...'", () {
        final value = cases[89];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '..<'", () {
        final value = cases[90];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '!!'", () {
        final value = cases[91];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '??'", () {
        final value = cases[92];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '%%'", () {
        final value = cases[93];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '&&'", () {
        final value = cases[94];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '||'", () {
        final value = cases[95];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '?.'", () {
        final value = cases[96];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '?:'", () {
        final value = cases[97];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '++'", () {
        final value = cases[98];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '+++'", () {
        final value = cases[99];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '--'", () {
        final value = cases[100];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '---'", () {
        final value = cases[101];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '**'", () {
        final value = cases[102];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '***'", () {
        final value = cases[103];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '~='", () {
        final value = cases[104];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '~-'", () {
        final value = cases[105];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: 'www'", () {
        final value = cases[106];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '-~'", () {
        final value = cases[107];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '~@'", () {
        final value = cases[108];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '^='", () {
        final value = cases[109];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '?='", () {
        final value = cases[110];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '/='", () {
        final value = cases[111];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '/=='", () {
        final value = cases[112];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '-|'", () {
        final value = cases[113];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '_|_'", () {
        final value = cases[114];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '|-'", () {
        final value = cases[115];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '|='", () {
        final value = cases[116];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '||='", () {
        final value = cases[117];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#!'", () {
        final value = cases[118];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#='", () {
        final value = cases[119];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '##'", () {
        final value = cases[120];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '###'", () {
        final value = cases[121];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '####'", () {
        final value = cases[122];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#{'", () {
        final value = cases[123];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#['", () {
        final value = cases[124];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: ']#'", () {
        final value = cases[125];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#('", () {
        final value = cases[126];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#?'", () {
        final value = cases[127];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#_'", () {
        final value = cases[128];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '#_('", () {
        final value = cases[129];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '::='", () {
        final value = cases[130];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '.?'", () {
        final value = cases[131];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Fira Code: '===>'", () {
        final value = cases[132];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<-'", () {
        final value = cases[133];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<--'", () {
        final value = cases[134];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<---'", () {
        final value = cases[135];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<-----'", () {
        final value = cases[136];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '->'", () {
        final value = cases[137];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '-->'", () {
        final value = cases[138];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '--->'", () {
        final value = cases[139];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '----->'", () {
        final value = cases[140];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<->'", () {
        final value = cases[141];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<-->'", () {
        final value = cases[142];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<--->'", () {
        final value = cases[143];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<----->'", () {
        final value = cases[144];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<='", () {
        final value = cases[145];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<=='", () {
        final value = cases[146];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<==='", () {
        final value = cases[147];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<====='", () {
        final value = cases[148];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '=>'", () {
        final value = cases[149];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '==>'", () {
        final value = cases[150];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '===>'", () {
        final value = cases[151];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '=====>'", () {
        final value = cases[152];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<=>'", () {
        final value = cases[153];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<==>'", () {
        final value = cases[154];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<===>'", () {
        final value = cases[155];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<=====>'", () {
        final value = cases[156];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<!--'", () {
        final value = cases[157];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<!---'", () {
        final value = cases[158];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<!-----'", () {
        final value = cases[159];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: 'a:b'", () {
        final value = cases[160];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: 'a::b'", () {
        final value = cases[161];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: 'a:::b'", () {
        final value = cases[162];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: ':='", () {
        final value = cases[163];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: ':-'", () {
        final value = cases[164];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: ':+'", () {
        final value = cases[165];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '=:'", () {
        final value = cases[166];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '-:'", () {
        final value = cases[167];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '+:'", () {
        final value = cases[168];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<*'", () {
        final value = cases[169];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '*>'", () {
        final value = cases[170];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<*>'", () {
        final value = cases[171];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<**>'", () {
        final value = cases[172];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '<****>'", () {
        final value = cases[173];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '=='", () {
        final value = cases[174];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '!='", () {
        final value = cases[175];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '==='", () {
        final value = cases[176];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '!=='", () {
        final value = cases[177];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '===='", () {
        final value = cases[178];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Iosevka: '!==='", () {
        final value = cases[179];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<!--'", () {
        final value = cases[180];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '-->'", () {
        final value = cases[181];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<--'", () {
        final value = cases[182];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '->>'", () {
        final value = cases[183];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<<-'", () {
        final value = cases[184];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '->'", () {
        final value = cases[185];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<-'", () {
        final value = cases[186];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '=>'", () {
        final value = cases[187];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<=>'", () {
        final value = cases[188];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<==>'", () {
        final value = cases[189];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '==>'", () {
        final value = cases[190];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<=='", () {
        final value = cases[191];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '>>='", () {
        final value = cases[192];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '=<<'", () {
        final value = cases[193];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '--'", () {
        final value = cases[194];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: ':='", () {
        final value = cases[195];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '=:='", () {
        final value = cases[196];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '=='", () {
        final value = cases[197];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '!=='", () {
        final value = cases[198];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '!='", () {
        final value = cases[199];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<='", () {
        final value = cases[200];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '>='", () {
        final value = cases[201];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '//'", () {
        final value = cases[202];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '/**'", () {
        final value = cases[203];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '/*'", () {
        final value = cases[204];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '*/'", () {
        final value = cases[205];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '&&'", () {
        final value = cases[206];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '.&'", () {
        final value = cases[207];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '||'", () {
        final value = cases[208];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '!!'", () {
        final value = cases[209];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '::'", () {
        final value = cases[210];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '>>'", () {
        final value = cases[211];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '<<'", () {
        final value = cases[212];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test(r"Monoid: '¯\_(ツ)_/¯'", () {
        final value = cases[213];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Monoid: '__'", () {
        final value = cases[214];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
      test("Ubuntu Mono: '==>'", () {
        final value = cases[215];
        final result = _font(value.font).findLigatures(value.input);
        expect(result.outputGlyphs, value.glyphs);
        expect(result.contextRanges, value.ranges);
      });
    });
    group('findLigatureRanges', () {
      test("Fira Code: 'abc'", () {
        final value = cases[0];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '.='", () {
        final value = cases[1];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '..='", () {
        final value = cases[2];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '.-'", () {
        final value = cases[3];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: ':='", () {
        final value = cases[4];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=:='", () {
        final value = cases[5];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=!='", () {
        final value = cases[6];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '__'", () {
        final value = cases[7];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=='", () {
        final value = cases[8];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '!='", () {
        final value = cases[9];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '==='", () {
        final value = cases[10];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '!=='", () {
        final value = cases[11];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=/='", () {
        final value = cases[12];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<-<'", () {
        final value = cases[13];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<<-'", () {
        final value = cases[14];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<--'", () {
        final value = cases[15];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<-'", () {
        final value = cases[16];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<->'", () {
        final value = cases[17];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '->'", () {
        final value = cases[18];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '-->'", () {
        final value = cases[19];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '->>'", () {
        final value = cases[20];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>->'", () {
        final value = cases[21];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<=<'", () {
        final value = cases[22];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<<='", () {
        final value = cases[23];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<=='", () {
        final value = cases[24];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<=>'", () {
        final value = cases[25];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=>'", () {
        final value = cases[26];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '==>'", () {
        final value = cases[27];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=>>'", () {
        final value = cases[28];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>=>'", () {
        final value = cases[29];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>>='", () {
        final value = cases[30];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>>-'", () {
        final value = cases[31];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>-'", () {
        final value = cases[32];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<~>'", () {
        final value = cases[33];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '-<'", () {
        final value = cases[34];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '-<<'", () {
        final value = cases[35];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '=<<'", () {
        final value = cases[36];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<~~'", () {
        final value = cases[37];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<~'", () {
        final value = cases[38];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '~~'", () {
        final value = cases[39];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '~>'", () {
        final value = cases[40];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '~~>'", () {
        final value = cases[41];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<<<'", () {
        final value = cases[42];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<<'", () {
        final value = cases[43];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<='", () {
        final value = cases[44];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<>'", () {
        final value = cases[45];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>='", () {
        final value = cases[46];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>>'", () {
        final value = cases[47];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '>>>'", () {
        final value = cases[48];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '{.'", () {
        final value = cases[49];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '{|'", () {
        final value = cases[50];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '[|'", () {
        final value = cases[51];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<:'", () {
        final value = cases[52];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: ':>'", () {
        final value = cases[53];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '|]'", () {
        final value = cases[54];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '|}'", () {
        final value = cases[55];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '.}'", () {
        final value = cases[56];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<|||'", () {
        final value = cases[57];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<||'", () {
        final value = cases[58];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<|'", () {
        final value = cases[59];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<|>'", () {
        final value = cases[60];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '|>'", () {
        final value = cases[61];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '||>'", () {
        final value = cases[62];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '|||>'", () {
        final value = cases[63];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test(r"Fira Code: '<$'", () {
        final value = cases[64];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test(r"Fira Code: '<$>'", () {
        final value = cases[65];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test(r"Fira Code: '$>'", () {
        final value = cases[66];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<+'", () {
        final value = cases[67];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<+>'", () {
        final value = cases[68];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '+>'", () {
        final value = cases[69];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<*'", () {
        final value = cases[70];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<*>'", () {
        final value = cases[71];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '*>'", () {
        final value = cases[72];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '/*'", () {
        final value = cases[73];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '*/'", () {
        final value = cases[74];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '///'", () {
        final value = cases[75];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '//'", () {
        final value = cases[76];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '</'", () {
        final value = cases[77];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '<!--'", () {
        final value = cases[78];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '</>'", () {
        final value = cases[79];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '/>'", () {
        final value = cases[80];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '0xff'", () {
        final value = cases[81];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '10x10'", () {
        final value = cases[82];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '9:45'", () {
        final value = cases[83];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '[:]'", () {
        final value = cases[84];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: ';;'", () {
        final value = cases[85];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '::'", () {
        final value = cases[86];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: ':::'", () {
        final value = cases[87];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '..'", () {
        final value = cases[88];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '...'", () {
        final value = cases[89];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '..<'", () {
        final value = cases[90];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '!!'", () {
        final value = cases[91];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '??'", () {
        final value = cases[92];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '%%'", () {
        final value = cases[93];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '&&'", () {
        final value = cases[94];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '||'", () {
        final value = cases[95];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '?.'", () {
        final value = cases[96];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '?:'", () {
        final value = cases[97];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '++'", () {
        final value = cases[98];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '+++'", () {
        final value = cases[99];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '--'", () {
        final value = cases[100];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '---'", () {
        final value = cases[101];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '**'", () {
        final value = cases[102];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '***'", () {
        final value = cases[103];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '~='", () {
        final value = cases[104];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '~-'", () {
        final value = cases[105];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: 'www'", () {
        final value = cases[106];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '-~'", () {
        final value = cases[107];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '~@'", () {
        final value = cases[108];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '^='", () {
        final value = cases[109];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '?='", () {
        final value = cases[110];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '/='", () {
        final value = cases[111];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '/=='", () {
        final value = cases[112];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '-|'", () {
        final value = cases[113];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '_|_'", () {
        final value = cases[114];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '|-'", () {
        final value = cases[115];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '|='", () {
        final value = cases[116];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '||='", () {
        final value = cases[117];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#!'", () {
        final value = cases[118];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#='", () {
        final value = cases[119];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '##'", () {
        final value = cases[120];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '###'", () {
        final value = cases[121];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '####'", () {
        final value = cases[122];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#{'", () {
        final value = cases[123];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#['", () {
        final value = cases[124];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: ']#'", () {
        final value = cases[125];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#('", () {
        final value = cases[126];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#?'", () {
        final value = cases[127];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#_'", () {
        final value = cases[128];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '#_('", () {
        final value = cases[129];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '::='", () {
        final value = cases[130];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '.?'", () {
        final value = cases[131];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Fira Code: '===>'", () {
        final value = cases[132];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<-'", () {
        final value = cases[133];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<--'", () {
        final value = cases[134];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<---'", () {
        final value = cases[135];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<-----'", () {
        final value = cases[136];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '->'", () {
        final value = cases[137];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '-->'", () {
        final value = cases[138];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '--->'", () {
        final value = cases[139];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '----->'", () {
        final value = cases[140];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<->'", () {
        final value = cases[141];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<-->'", () {
        final value = cases[142];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<--->'", () {
        final value = cases[143];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<----->'", () {
        final value = cases[144];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<='", () {
        final value = cases[145];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<=='", () {
        final value = cases[146];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<==='", () {
        final value = cases[147];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<====='", () {
        final value = cases[148];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '=>'", () {
        final value = cases[149];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '==>'", () {
        final value = cases[150];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '===>'", () {
        final value = cases[151];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '=====>'", () {
        final value = cases[152];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<=>'", () {
        final value = cases[153];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<==>'", () {
        final value = cases[154];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<===>'", () {
        final value = cases[155];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<=====>'", () {
        final value = cases[156];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<!--'", () {
        final value = cases[157];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<!---'", () {
        final value = cases[158];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<!-----'", () {
        final value = cases[159];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: 'a:b'", () {
        final value = cases[160];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: 'a::b'", () {
        final value = cases[161];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: 'a:::b'", () {
        final value = cases[162];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: ':='", () {
        final value = cases[163];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: ':-'", () {
        final value = cases[164];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: ':+'", () {
        final value = cases[165];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '=:'", () {
        final value = cases[166];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '-:'", () {
        final value = cases[167];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '+:'", () {
        final value = cases[168];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<*'", () {
        final value = cases[169];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '*>'", () {
        final value = cases[170];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<*>'", () {
        final value = cases[171];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<**>'", () {
        final value = cases[172];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '<****>'", () {
        final value = cases[173];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '=='", () {
        final value = cases[174];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '!='", () {
        final value = cases[175];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '==='", () {
        final value = cases[176];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '!=='", () {
        final value = cases[177];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '===='", () {
        final value = cases[178];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Iosevka: '!==='", () {
        final value = cases[179];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<!--'", () {
        final value = cases[180];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '-->'", () {
        final value = cases[181];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<--'", () {
        final value = cases[182];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '->>'", () {
        final value = cases[183];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<<-'", () {
        final value = cases[184];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '->'", () {
        final value = cases[185];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<-'", () {
        final value = cases[186];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '=>'", () {
        final value = cases[187];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<=>'", () {
        final value = cases[188];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<==>'", () {
        final value = cases[189];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '==>'", () {
        final value = cases[190];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<=='", () {
        final value = cases[191];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '>>='", () {
        final value = cases[192];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '=<<'", () {
        final value = cases[193];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '--'", () {
        final value = cases[194];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: ':='", () {
        final value = cases[195];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '=:='", () {
        final value = cases[196];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '=='", () {
        final value = cases[197];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '!=='", () {
        final value = cases[198];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '!='", () {
        final value = cases[199];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<='", () {
        final value = cases[200];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '>='", () {
        final value = cases[201];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '//'", () {
        final value = cases[202];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '/**'", () {
        final value = cases[203];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '/*'", () {
        final value = cases[204];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '*/'", () {
        final value = cases[205];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '&&'", () {
        final value = cases[206];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '.&'", () {
        final value = cases[207];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '||'", () {
        final value = cases[208];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '!!'", () {
        final value = cases[209];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '::'", () {
        final value = cases[210];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '>>'", () {
        final value = cases[211];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '<<'", () {
        final value = cases[212];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test(r"Monoid: '¯\_(ツ)_/¯'", () {
        final value = cases[213];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Monoid: '__'", () {
        final value = cases[214];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
      test("Ubuntu Mono: '==>'", () {
        final value = cases[215];
        expect(
          _font(value.font).findLigatureRanges(value.input),
          value.ranges,
        );
      });
    });
    group('caching', () {
      test('findLigatures caches successive calls correctly', () {
        final font = _newFont('Fira Code', cacheSize: 100);
        final first = font.findLigatures('in --> out');
        expect(
          font.findLigatures('in --> out').outputGlyphs,
          first.outputGlyphs,
        );
        expect(
          font.findLigatures('in --> out').contextRanges,
          first.contextRanges,
        );
      });
      test('findLigatureRanges caches successive calls correctly', () {
        final font = _newFont('Fira Code', cacheSize: 100);
        final first = font.findLigatureRanges('in --> out');
        expect(font.findLigatureRanges('in --> out'), first);
      });
      test(
        'caches calls to findLigatures after findLigatureRanges correctly',
        () {
          final uncached = _newFont('Fira Code');
          final expectedRanges = uncached.findLigatureRanges('in --> out');
          final expectedLigatures = uncached.findLigatures('in --> out');
          final font = _newFont('Fira Code', cacheSize: 100);
          final ranges = font.findLigatureRanges('in --> out');
          final ligatures = font.findLigatures('in --> out');
          expect(ranges, expectedRanges);
          expect(ligatures.outputGlyphs, expectedLigatures.outputGlyphs);
          expect(ligatures.contextRanges, expectedLigatures.contextRanges);
          expect(ranges, ligatures.contextRanges);
        },
      );
      test(
        'caches calls to findLigatureRanges after findLigatures correctly',
        () {
          final uncached = _newFont('Fira Code');
          final expectedLigatures = uncached.findLigatures('in --> out');
          final expectedRanges = uncached.findLigatureRanges('in --> out');
          final font = _newFont('Fira Code', cacheSize: 100);
          final ligatures = font.findLigatures('in --> out');
          final ranges = font.findLigatureRanges('in --> out');
          expect(ligatures.outputGlyphs, expectedLigatures.outputGlyphs);
          expect(ligatures.contextRanges, expectedLigatures.contextRanges);
          expect(ranges, expectedRanges);
          expect(ligatures.contextRanges, ranges);
        },
      );
    });
  });
}

final class _Case {
  const _Case(this.font, this.input, this.glyphs, this.ranges);
  final String font;
  final String input;
  final List<int> glyphs;
  final List<(int, int)> ranges;
}

List<_Case> _loadCases() {
  final decoded =
      jsonDecode(File(_fixturePath('index_cases.json')).readAsStringSync())
          as Map<String, Object?>;
  return (decoded['cases']! as List<Object?>).map((value) {
    final item = value! as Map<String, Object?>;
    return _Case(
      item['font']! as String,
      item['input']! as String,
      (item['glyphs']! as List<Object?>).cast<int>(),
      (item['ranges']! as List<Object?>).map((range) {
        final values = (range! as List<Object?>).cast<int>();
        return (values[0], values[1]);
      }).toList(),
    );
  }).toList();
}

final Map<String, TerminalLigatureFont> _fonts =
    <String, TerminalLigatureFont>{};
final Map<String, Uint8List> _fontBytes = <String, Uint8List>{};

TerminalLigatureFont _font(String name) =>
    _fonts.putIfAbsent(name, () => _newFont(name));

TerminalLigatureFont _newFont(String name, {int cacheSize = 0}) =>
    TerminalLigatureFont.fromBytes(
      _fontBytes.putIfAbsent(name, () {
        final encoded = File(
          _fixturePath(_fontFiles[name]!),
        ).readAsStringSync().replaceAll(RegExp(r'\s'), '');
        return Uint8List.fromList(gzip.decode(base64.decode(encoded)));
      }),
      cacheSize: cacheSize,
    );

String _fixturePath(String name) {
  final root = Directory.current.path.endsWith('termworld')
      ? 'test'
      : 'packages/termworld/test';
  return '$root/fixtures/xterm_ligatures/$name';
}

const Map<String, String> _fontFiles = <String, String>{
  'Fira Code': 'FiraCode-Regular.otf.gz.b64',
  'Iosevka': 'iosevka-regular.ttf.gz.b64',
  'Monoid': 'Monoid-Regular.ttf.gz.b64',
  'Ubuntu Mono': 'UbuntuMono-Regular.ttf.gz.b64',
};

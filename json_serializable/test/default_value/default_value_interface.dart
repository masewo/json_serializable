// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart=2.12

abstract class DefaultValue {
  bool fieldBool;
  String fieldString;
  int fieldInt;
  double fieldDouble;
  List fieldListEmpty;
  Map fieldMapEmpty;
  Set fieldSetEmpty;
  List<int> fieldListSimple;
  Set<String> fieldSetSimple;
  Map<String, int> fieldMapSimple;
  Map<String, List<String>> fieldMapListString;
  Greek fieldEnum;

  DefaultValue(
    this.fieldBool,
    this.fieldString,
    this.fieldInt,
    this.fieldDouble,
    this.fieldListEmpty,
    this.fieldSetEmpty,
    this.fieldMapEmpty,
    this.fieldListSimple,
    this.fieldSetSimple,
    this.fieldMapSimple,
    this.fieldMapListString,
    this.fieldEnum,
  );
}

enum Greek { alpha, beta, gamma, delta }

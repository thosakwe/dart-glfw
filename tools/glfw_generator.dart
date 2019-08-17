/// Consumes "glfw3.h" header file and generates bindings for
/// libglfw_extension.so
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:quiver/collection.dart';

String outPath;
main(List<String> args) async {
  var parser = new ArgParser()
    ..addOption('glfw3_path',
        help: 'path to directory containing glfw3.h',
        abbr: 'g',
        valueHelp: 'path')
    ..addOption('out',
        help: 'path to output directory', abbr: 'o', valueHelp: 'path')
    ..addFlag('dev_print_maps',
        help: 'extension development: prints unused and used keys for mappings',
        hide: true)
    ..addFlag('help', abbr: 'h', negatable: false);
  var results = parser.parse(args);

  if (results.wasParsed('help')) {
    stdout.writeln(parser.usage);
    exit(0);
  }

  toErr(String msg, [int exitVal = 1]) {
    stderr..writeln(msg)..writeln(parser.usage);
    exit(exitVal);
  }

  if (!results.wasParsed('glfw3_path')) {
    toErr('error: --glfw3_path must be provided');
  }
  var glfwPath = results['glfw3_path'];

  outPath = 'generated';
  if (results.wasParsed('out')) {
    outPath = results['out'];
  }
  outPath = (await new Directory('$outPath').create()).path;

  var defines = [];
  var calls = [];

  var readStream = new File(path.join(glfwPath, 'glfw3.h')).openRead();
  var defineRegex = new RegExp(r'#define GLFW_[^ ]+\s+\d+');
  await for (var line in readStream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(new LineSplitter())) {
    if (line.contains(defineRegex)) {
      defines.add(line.substring('#define '.length).trim());
    } else if (line.startsWith('GLFWAPI ')) {
      calls.add(line.replaceAll('GLFWAPI ', '').trim());
    }
  }

  var consts = <CConst>[];
  for (var def in defines) {
    consts.add(new CConst(def));
  }

  var decls = <CDecl>[];
  for (var call in calls) {
    decls.add(new CDecl(call));
  }

  await writeFunctionListH(decls);
  await writeConstantsDart(consts);
  await writeFunctionListC(decls);
  await writeBindingsH(decls);
  await writeNativeFunctions(decls);
  await writeBindingsC(decls);

  if (results.wasParsed('dev_print_maps')) {
    MapTracker.maps.forEach((name, map) {
      var keys = map.delegate.keys.toSet();
      var diff = keys.difference(map.validKeys);
      if (diff.isNotEmpty) {
        print('====[map report: $name]====');
        print('  unused keys: $diff');
        print('  used keys: ${map.validKeys}');
      }
    });
  }
}

const String copyright = '''
// Copyright (c) 2015, the Dart GLFW extension authors. All rights reserved.
// Please see the AUTHORS file for details. Use of this source code is governed
// by a BSD-style license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

// This file is auto-generated by scripts in the tools/ directory.
''';

/// Delegate Map that tracks used keys.
class MapTracker<K, V> extends DelegatingMap<K, V> {
  static Map maps = <String, Map>{};

  Map<K, V> delegate;
  MapTracker(String name, this.delegate) {
    maps[name] = this;
  }

  Set validKeys = new Set();

  @override
  operator [](Object key) {
    if (delegate.containsKey(key)) {
      validKeys.add(key);
    }
    return delegate[key];
  }

  @override
  void forEach(void f(K key, V value)) {
    validKeys.addAll(delegate.keys);
    delegate.forEach(f);
  }
}

/// Maps C types to Dart types.
var typeMap = new MapTracker("_typeMap", _typeMap);
const _typeMap = const <String, String>{
  "int": "int",
  "uint64_t": "int",
  "void": "void",
  "const char*": "String",
  "double": "double",
  "float": "double",
  "GLFWmonitor*": "GLFWmonitor",
  "GLFWwindow*": "GLFWwindow",
  "GLFWcursor*": "GLFWcursor",
  "const GLFWvidmode*": "GLFWvidmode",
  "const GLFWgammaramp*": "GLFWgammaramp",
  "const GLFWimage*": "GLFWimage",
  "GLFWerrorfun": "GLFWerrorfun",
  "GLFWmonitorfun": "GLFWmonitorfun",
  "GLFWjoystickfun": "GLFWjoystickfun",
  "GLFWwindowposfun": "GLFWwindowposfun",
  "GLFWwindowsizefun": "GLFWwindowsizefun",
  "GLFWwindowclosefun": "GLFWwindowclosefun",
  "GLFWwindowrefreshfun": "GLFWwindowrefreshfun",
  "GLFWwindowfocusfun": "GLFWwindowfocusfun",
  "GLFWwindowiconifyfun": "GLFWwindowiconifyfun",
  "GLFWframebuffersizefun": "GLFWframebuffersizefun",
  "GLFWkeyfun": "GLFWkeyfun",
  "GLFWcharfun": "GLFWcharfun",
  "GLFWcharmodsfun": "GLFWcharmodsfun",
  "GLFWmousebuttonfun": "GLFWmousebuttonfun",
  "GLFWcursorposfun": "GLFWcursorposfun",
  "GLFWcursorenterfun": "GLFWcursorenterfun",
  "GLFWscrollfun": "GLFWscrollfun",
  "GLFWdropfun": "GLFWdropfun",
};

var glfwDartCallbackTypedefs =
    new MapTracker("_glfwDartCallbackTypedefs", _glfwDartCallbackTypedefs);
Map _glfwDartCallbackTypedefs = {
  "GLFWerrorfun": [
    ["int", "error"],
    ["String", "description"]
  ],
  "GLFWwindowposfun": [
    ["GLFWwindow", "window"],
    ["int", "xpos"],
    ["int", "ypos"]
  ],
  "GLFWwindowsizefun": [
    ["GLFWwindow", "window"],
    ["int", "width"],
    ["int", "height"]
  ],
  "GLFWwindowclosefun": [
    ["GLFWwindow", "window"]
  ],
  "GLFWwindowrefreshfun": [
    ["GLFWwindow", "window"]
  ],
  "GLFWwindowfocusfun": [
    ["GLFWwindow", "window"],
    ["int", "focused"]
  ],
  "GLFWwindowiconifyfun": [
    ["GLFWwindow", "window"],
    ["int", "iconified"]
  ],
  "GLFWframebuffersizefun": [
    ["GLFWwindow", "window"],
    ["int", "width"],
    ["int", "height"]
  ],
  "GLFWmousebuttonfun": [
    ["GLFWwindow", "window"],
    ["int", "button"],
    ["int", "action"],
    ["int", "mods"]
  ],
  "GLFWcursorposfun": [
    ["GLFWwindow", "window"],
    ["double", "xpos"],
    ["double", "ypos"]
  ],
  "GLFWcursorenterfun": [
    ["GLFWwindow", "window"],
    ["int", "entered"]
  ],
  "GLFWscrollfun": [
    ["GLFWwindow", "window"],
    ["double", "xoffset"],
    ["double", "yoffset"]
  ],
  "GLFWkeyfun": [
    ["GLFWwindow", "window"],
    ["int", "key"],
    ["int", "scancode"],
    ["int", "action"],
    ["int", "mods"]
  ],
  "GLFWcharfun": [
    ["GLFWwindow", "window"],
    ["int", "codepoint"]
  ],
  "GLFWcharmodsfun": [
    ["GLFWwindow", "window"],
    ["int", "codepoint"],
    ["int", "mods"]
  ],
  "GLFWdropfun": [
    ["GLFWwindow", "window"],
    ["int", "count"],
    ["List<String>", "paths"]
  ],
  "GLFWmonitorfun": [
    ["GLFWmonitor", "monitor"],
    ["int", "event"]
  ],
  "GLFWjoystickfun": [
    ["int", "joy"],
    ["int", "event"]
  ],
};

var glfwCCallbackTypedefs =
    new MapTracker("_glfwCCallbackTypedefs", _glfwCCallbackTypedefs);
Map _glfwCCallbackTypedefs = {
  "GLFWerrorfun": [
    ["int", "error"],
    ["const char*", "description"]
  ],
  "GLFWwindowposfun": [
    ["GLFWwindow*", "window"],
    ["int", "xpos"],
    ["int", "ypos"]
  ],
  "GLFWwindowsizefun": [
    ["GLFWwindow*", "window"],
    ["int", "width"],
    ["int", "height"]
  ],
  "GLFWwindowclosefun": [
    ["GLFWwindow*", "window"]
  ],
  "GLFWwindowrefreshfun": [
    ["GLFWwindow*", "window"]
  ],
  "GLFWwindowfocusfun": [
    ["GLFWwindow*", "window"],
    ["int", "focused"]
  ],
  "GLFWwindowiconifyfun": [
    ["GLFWwindow*", "window"],
    ["int", "iconified"]
  ],
  "GLFWframebuffersizefun": [
    ["GLFWwindow*", "window"],
    ["int", "width"],
    ["int", "height"]
  ],
  "GLFWmousebuttonfun": [
    ["GLFWwindow*", "window"],
    ["int", "button"],
    ["int", "action"],
    ["int", "mods"]
  ],
  "GLFWcursorposfun": [
    ["GLFWwindow*", "window"],
    ["double", "xpos"],
    ["double", "ypos"]
  ],
  "GLFWcursorenterfun": [
    ["GLFWwindow*", "window"],
    ["int", "entered"]
  ],
  "GLFWscrollfun": [
    ["GLFWwindow*", "window"],
    ["double", "xoffset"],
    ["double", "yoffset"]
  ],
  "GLFWkeyfun": [
    ["GLFWwindow*", "window"],
    ["int", "key"],
    ["int", "scancode"],
    ["int", "action"],
    ["int", "mods"]
  ],
  "GLFWcharfun": [
    ["GLFWwindow*", "window"],
    ["unsigned int", "codepoint"]
  ],
  "GLFWcharmodsfun": [
    ["GLFWwindow*", "window"],
    ["unsigned int", "codepoint"],
    ["int", "mods"]
  ],
  "GLFWdropfun": [
    ["GLFWwindow*", "window"],
    ["int", "count"],
    ["const char**", "paths"]
  ],
  "GLFWmonitorfun": [
    ["GLFWmonitor*", "monitor"],
    ["int", "event"]
  ],
  "GLFWjoystickfun": [
    ["int", "joy"],
    ["int", "event"]
  ],
};

/// If the return type is "GLboolean", return bool back to dart code as
/// conditional statements expect boolean evaluation in Dart.
var glfwReturnTypeHintMap =
    new MapTracker("_glfwReturnTypeHintMap", _glfwReturnTypeHintMap);
Map _glfwReturnTypeHintMap = {
  "glfwInit": "bool",
  "glfwJoystickPresent": "bool",
  "glfwExtensionSupported": "bool",
};

/// Handle tricky callbacks -
/// CODEFU: This is only printed in one location....
var glfwCallbackArgumentOverrides = new MapTracker(
    "_glfwCallbackArgumentOverrides", _glfwCallbackArgumentOverrides);
Map _glfwCallbackArgumentOverrides = {
  "GLFWdropfun": '''static Dart_Handle dart_GLFWdropfun_cb = NULL;

void _GLFWdropfun_cb(GLFWwindow* window, int count, const char** paths) {
  Dart_Handle arguments[3];
  arguments[0] = HANDLE(NewGLFWwindow(window));
  arguments[1] = HANDLE(Dart_NewInteger(count));
  arguments[2] = HANDLE(Dart_NewListOf(Dart_CoreType_String, count));
  for (int i = 0; i<count; i++) {
    HANDLE(Dart_ListSetAt(arguments[2], i, Dart_NewStringFromCString(paths[i])));
  }
  HANDLE_INVOKE(Dart_InvokeClosure(dart_GLFWscrollfun_cb, 3, arguments));
}
'''
};

/// Maps special GLFW API arguments to Dart types.
///
/// NOTE: This is **very** brittle.
var argumentTypeHint = new MapTracker("_argumentTypeHint", _argumentTypeHint);
const _argumentTypeHint = const <String, String>{
  "int focused": "bool",
  "int iconified": "bool",
  "int entered": "bool",
  "unsigned int codepoint": "int",
};

String simpleHandleC(String type, String name) => '''
  ${type}* $name = GetNativePointer<$type>(${name}_obj);
''';

String nonOpaqueHandleC(String type, String name) => '''
  ${type}* ${name} = NULL;
  if (!Dart_IsNull(${name}_obj)) {
    ${name} = New${type}FromDart(${name}_obj);
  }
''';

var glfwHandleC = new MapTracker("_glfwHandleC", _glfwHandleC);
Map _glfwHandleC = <String, Function>{
  "GLFWmonitor": simpleHandleC,
  "GLFWwindow": simpleHandleC,
  "GLFWcursor": simpleHandleC,
  "GLFWvidmode": nonOpaqueHandleC,
  "GLFWgammaramp": nonOpaqueHandleC,
  "GLFWimage": nonOpaqueHandleC,
};

typedef String FreeHandle(String name);
var needsFree = new MapTracker("_needsFree", _needsFree);
Map _needsFree = <String, FreeHandle>{
  "GLFWvidmode": (name) => '''
      if (${name} != NULL) {
        free(${name});
      }''',
  "GLFWgammaramp": (name) => '''
        if (${name} != NULL) {
          free(${name}->red);
          free(${name}->green);
          free(${name}->blue);
          free(${name});
        }''',
  "GLFWimage": (name) => '''
        if (${name} != NULL) {
          free(${name}->pixels);
          free(${name});
        }''',
  "TypedData": (name) => '''
    if (!Dart_IsNull(${name}_obj)) {
      HANDLE(Dart_TypedDataReleaseData(${name}_obj));
    }
    '''
};

typedef String NewHandle(name);
var newHandleMap = new MapTracker("_newHandleMap", _newHandleMap);
Map _newHandleMap = <String, NewHandle>{
  "int": (name) => "Dart_NewInteger($name)",
  "int64_t": (name) => "Dart_NewInteger($name)",
  "uint64_t": (name) => "Dart_NewIntegerFromUint64($name)",
  "double": (name) => "Dart_NewDouble($name)",
  "float": (name) => "Dart_NewDouble($name)",
  "bool": (name) => "Dart_NewBoolean($name)",
  "const char*": (name) => "Dart_NewStringFromCString($name)",
  "GLFWmonitor*": (name) => "NewGLFWmonitor($name)",
  "GLFWwindow*": (name) => "NewGLFWwindow($name)",
  "GLFWcursor*": (name) => "NewGLFWcursor($name)",
  "const GLFWvidmode*": (name) => "NewGLFWvidmode($name)",
  "const GLFWgammaramp*": (name) => "NewGLFWgammaramp($name)",
  "const GLFWimage*": (name) => "NewGLFWimage($name)",
};

writeFunctionListH(List<CDecl> decls) async =>
    new File('$outPath/function_list.h').writeAsString('''
$copyright
#ifndef DART_GLFW_LIB_SRC_GENERATED_FUNCTION_LIST_H_
#define DART_GLFW_LIB_SRC_GENERATED_FUNCTION_LIST_H_

#include "dart_api.h"

struct FunctionLookup {
  const char* name;
  Dart_NativeFunction function;
};

extern const struct FunctionLookup *function_list;

#endif // DART_GLFW_LIB_SRC_GENERATED_FUNCTION_LIST_H_
''');

writeConstantsDart(List<CConst> consts) async {
  var sink = new File('$outPath/glfw_constants.dart').openWrite()
    ..write(copyright)
    ..writeln('\n// Generated GLFW constants.')
    ..writeAll(consts, '\n');
  return sink.close();
}

writeNativeFunctions(List<CDecl> decls) async {
  var sink = new File('$outPath/glfw_native_functions.dart').openWrite()
    ..write(copyright)
    ..writeln()
    ..writeln('/// Dart definitions for GLFW native extension.')
    ..writeln('part of glfw;')
    ..writeln();

  glfwDartCallbackTypedefs.forEach((name, args) {
    args = args.map((arg) {
      var ele = argumentTypeHint[arg.join(" ")];
      return (ele != null) ? "$ele ${arg[1]}" : "${arg[0]} ${arg[1]}";
    }).toList();
    sink.writeln('typedef void $name(${args.join(', ')});');
  });
  sink.writeln();

  for (var decl in decls) {
    if (decl.hasManualBinding || decl.needsManualBinding) continue;
    sink.write('${decl.dartReturnType} ${decl.name}');
    if (decl.dartArguments.isEmpty || decl.arguments.first.right == "void") {
      sink.write('()');
    } else {
      sink.write('(${decl.dartArguments.join(', ')})');
    }
    sink.writeln(' native "${decl.name}";');
  }
  return sink.close();
}

writeFunctionListC(List<CDecl> decls) async {
  functionListLine(CDecl c) => '    '
      '${c.needsManualBinding && !c.hasManualBinding ? "// " : ""}'
      '{"${c.name}", ${c.nativeName}},';

  var sink = new File('$outPath/function_list.cc').openWrite()
    ..write(copyright)
    ..write('''

#include <stdlib.h>

#include "../manual_bindings.h"
#include "function_list.h"
#include "glfw_bindings.h"

// function_list is used by ResolveName in lib/src/glfw_extension.cc.
const struct FunctionLookup _function_list[] = {
''')
    ..write(decls.map(functionListLine).join('\n'))
    ..writeln()
    ..write('''
    {NULL, NULL}};
// This prevents the compiler from complaining about initializing improperly.
const struct FunctionLookup *function_list = _function_list;
''');
  return sink.close();
}

writeBindingsH(List<CDecl> decls) async {
  var sink = new File('$outPath/glfw_bindings.h').openWrite()
    ..write(copyright)
    ..write('''

#ifndef DART_GLFW_LIB_SRC_GENERATED_GENERATED_BINDINGS_H_
#define DART_GLFW_LIB_SRC_GENERATED_GENERATED_BINDINGS_H_

#include "dart_api.h"
''');
  sink
    ..writeln()
    ..writeln('// Header file for generated GLFW function bindings.')
    ..writeln()
    ..writeln(decls
        .where((d) => !d.hasManualBinding && !d.needsManualBinding)
        .map((d) => 'void ${d.nativeName}(Dart_NativeArguments arguments);')
        .join('\n'))
    ..writeln()
    ..write('#endif // DART_GLFW_LIB_SRC_GENERATED_GENERATED_BINDINGS_H_')
    ..writeln();
  return sink.close();
}

/// Unpacks non-native dart parameters to obj pointers.
nativeToPtr(Pair arg, int index) {
  String type = arg.left;
  String typeNoPtr = arg.left.split('*')[0];
  String name = arg.right;
  return '''
  Dart_Handle ${name}_obj = HANDLE(Dart_GetNativeArgument(arguments, $index));
  $type $name = GetNativePointer<$typeNoPtr>(${name}_obj);
''';
}

/// Generates the "actual" native callback function and the dart-native wrapper,
/// binding the dart-land callback.
writeCallbackHandler(CDecl decl) {
  StringBuffer sbuff = new StringBuffer();
  String cbType = decl.returnType;
  if (glfwCallbackArgumentOverrides.containsKey(cbType)) {
    sbuff.writeln(glfwCallbackArgumentOverrides[cbType]);
  } else {
    var cCallbackSig = glfwCCallbackTypedefs[cbType];
    int size = cCallbackSig.length;

    var c_args = cCallbackSig.map((a) => a.join(' ')).join(', ');

    var realCb = '_${cbType}_cb';
    sbuff.writeln('''
static Dart_Handle dart_${cbType}_cb = NULL;

void $realCb($c_args) {
  Dart_Handle arguments[$size];''');

    int i = 0;
    for (var args in cCallbackSig) {
      var type = args[0];
      var name = args[1];
      var ele = argumentTypeHint[args.join(" ")] ?? type;
      var mapper = newHandleMap[ele];
      if (mapper == null) {
        mapper = newHandleMap[type];
      }
      if (mapper == null) {
        stderr
          ..writeln("Error generating native 'actual' callback for: $decl")
          ..write("The follow will not be written because we cannot allocate ")
          ..writeln("a variable in the actual callback:")
          ..writeln("$sbuff");
        return "";
      }
      sbuff.writeln('  arguments[$i] = HANDLE(${mapper(name)});');
      i++;
    }
    sbuff.writeln('''
  HANDLE_INVOKE(Dart_InvokeClosure(dart_${cbType}_cb, $size, arguments));
}''');
  }

  // Now write the dart-native function.
  sbuff
    ..writeln('void ${decl.nativeName}(Dart_NativeArguments arguments) {')
    ..writeln('  TRACE_START(${decl.name}_);');
  // glfw3.h has "cbfun" parameter names for callbacks - switch those.
  var arguments = [];
  var natives = [];
  int i = 0;
  for (var arg in decl.arguments) {
    if (arg.right == "cbfun") {
      arguments.add('_${cbType}_cb');
      natives.add('''
  Dart_Handle new_${cbType}_cb =
     HANDLE(Dart_GetNativeArgument(arguments, $i));
  new_${cbType}_cb =
      HANDLE(Dart_NewPersistentHandle(new_${cbType}_cb));
''');
    } else {
      arguments.add(arg.right);
      var typer = dartTypeToArg[arg.left] ?? nativeToPtr;
      natives.add(typer(arg, i));
    }
    i++;
  }

  sbuff
    ..writeAll(natives)
    ..writeln('''
  Dart_Handle old_${cbType}_cb = Dart_Null();
  if (dart_${cbType}_cb != NULL) {
    old_${cbType}_cb =
      HandleError(Dart_HandleFromPersistent(dart_${cbType}_cb));
    Dart_DeletePersistentHandle(dart_${cbType}_cb);
  }
  dart_${cbType}_cb = new_${cbType}_cb;
  ${decl.name}(${arguments.join(', ')});
  Dart_SetReturnValue(arguments, old_${cbType}_cb);
  TRACE_END(${decl.name}_);
}''');
  return "$sbuff";
}

/// Writes out native C functions that handle unboxing Dart arguments and
/// calling the real library methods.
writeBindingsC(List<CDecl> decls) async {
  var sink = new File('$outPath/glfw_bindings.cc').openWrite();

  sink..write(copyright)..write('''

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <dart_api.h>
#include <GLFW/glfw3.h>

#include "../instantiate_glfw_classes.h"
#include "../util.h"
#include "glfw_bindings.h"

// Generated GLFW function bindings for Dart.

''');

  // This buffer allows us to work on a native binding and if we encoder a
  // problem, we skip writing it to the file and instead log our work.
  StringBuffer sbuff = new StringBuffer();

  // Create a binding function for each declaration in the GLFW header file.
  outer: // <- I totally forgot Dart has lables.
  for (var decl in decls) {
    // If the function has a manual binding, or we've detected that it needs
    // one, skip it.
    if (decl.needsManualBinding || decl.hasManualBinding) continue;

    sbuff.clear();

    // If this is a *Callback registering function, we need to write extra
    // code.
    var cb = glfwCCallbackTypedefs[decl.returnType];
    if (cb != null) {
      sink.write(writeCallbackHandler(decl));
      continue;
    }

    // Write the first line (return type, name, and arguments).
    sbuff
      ..writeln('void ${decl.nativeName}(Dart_NativeArguments arguments) {')
      ..writeln('  TRACE_START(${decl.name}_);');

    // For each argument, generate the code needed to extract it from the
    // Dart_NativeArguments structure.
    int i = 0;
    var arguments = [];
    for (var arg in decl.arguments) {
      if (arg.right == "void") continue;
      var dartArg = decl.dartArguments[i];
      var mapper = dartTypeToArg[dartArg.left];
      if (mapper == null) {
        mapper = glfwHandleC[dartArg.left];
        if (mapper != null) {
          mapper = (_, __) {
            return '''
Dart_Handle ${arg.right}_obj = HANDLE(Dart_GetNativeArgument(arguments, $i));
${glfwHandleC[dartArg.left](dartArg.left, arg.right)}
            ''';
          };
        } else {
          mapper = nativeToPtr;
        }
      }

      // Print an error if we were unable to generate native code and continue
      // with the next decl.
      if (mapper == null) {
        stderr
          ..writeln("Error trying to map arguments for: $decl")
          ..writeln("Work that is being thrown away (and may break!):")
          ..writeln("$sbuff");
        continue outer;
      }
      sbuff.writeln(mapper(arg, i));
      arguments.add(arg.right);
      i++;
    }

    // Be sure to capture the return value from the GLFW function call,
    // if necessary.
    var ret = "";
    var retHandle = "";
    if (decl.returnType != "void") {
      ret = '  ${decl.returnType} ret = ';
      Function mapper = dartTypeToRet[decl.dartReturnType];
      if (mapper == null) {
        mapper = newHandleMap[decl.returnType];
        if (mapper != null) {
          var nonNativeType = mapper('ret');
          mapper = () => '  Dart_SetReturnValue(arguments, '
              'HANDLE($nonNativeType));';
        }
      }
      if (mapper == null) {
        stderr.writeln("wtf ret: ${decl.name} ${decl.returnType}");
        stderr.writeln("wtf ret: ${decl}");
        stderr.writeln("wtf work: $sbuff");
        continue outer;
      }
      retHandle = mapper();
    }

    // Generate the actual GLFW function call, using the native arguments
    // extracted above.
    ret = '  $ret ${decl.name}(${arguments.join(", ")});';
    sbuff..writeln(ret)..writeln(retHandle);

    // If we acquired any data that needs freeing - do that here.
    for (var arg in decl.dartArguments) {
      var free = needsFree[arg.left]?.call(arg.right);
      if (free != null) sbuff.writeln(free);
    }

    sbuff..writeln('  TRACE_END(${decl.name}_);')..writeln('}')..writeln();
    sink.write(sbuff.toString());
  }
  return sink.close();
}

/// Map of Dart argument types to unpacking functions.
typedef DartTypeToC(Pair arg, int index);
final dartTypeToArg = <String, DartTypeToC>{
  'int': intToC,
  'double': doubleToC,
  'String': stringToC,
  'bool': boolToC,
  'TypedData': typedToC
};

/// Map of Dart return types to packing functions.
typedef DartTypeToRet();
final dartTypeToRet = <String, DartTypeToRet>{
  'int': intToRet,
  'double': doubleToRet,
  'String': stringToRet,
  'bool': boolToRet,
};

/// Unpacks Dart int arguments to C.
intToC(Pair arg, int index) {
  String name = arg.right;
  return '''
  int64_t $name;
  HANDLE(Dart_GetNativeIntegerArgument(arguments, $index, &$name));
''';
}

/// Unpacks Dart double arguments to C.
doubleToC(Pair arg, int index) {
  String name = arg.right;
  return '''
  double $name;
  HANDLE(Dart_GetNativeDoubleArgument(arguments, $index, &$name));
''';
}

/// Unpacks Dart bool arguments to C.
boolToC(Pair arg, int index) {
  String name = arg.right;
  return '''
  bool $name;
  HANDLE(Dart_GetNativeBooleanArgument(arguments, $index, &$name));
''';
}

/// Unpacks Dart String arguments to C.
stringToC(Pair arg, int index) {
  String name = arg.right;
  return '''
  void* ${name}_peer = NULL;
  Dart_Handle ${name}_arg = HANDLE(Dart_GetNativeStringArgument(arguments, $index, (void**)&${name}_peer));
  const char *${name} = NULL;
  HANDLE(Dart_StringToCString(${name}_arg, &${name}));
''';
}

/// Unpacks Dart TypedData arguments to C.
typedToC(Pair arg, int index) {
  String name = arg.right;
  String type = arg.left;
  return '''
  Dart_Handle ${name}_obj = HANDLE(Dart_GetNativeArgument(arguments, $index));
  void* ${name}_data = nullptr;
  Dart_TypedData_Type ${name}_typeddata_type;
  intptr_t ${name}_typeddata_length;
  if (!Dart_IsNull(${name}_obj)) {
    HANDLE(Dart_TypedDataAcquireData(${name}_obj, &${name}_typeddata_type, &${name}_data, &${name}_typeddata_length));
  }
  $type $name = static_cast<$type>(${name}_data);
''';
}

/// Converts GLFW int to Dart int for return.
intToRet() => '  Dart_SetIntegerReturnValue(arguments, ret);';

/// Converts GLFW float to Dart double for return.
doubleToRet() => '  Dart_SetDoubleReturnValue(arguments, ret);';

/// Converts GLFW boolean to Dart bool for return.
boolToRet() => '  Dart_SetBooleanReturnValue(arguments, ret);';

/// Converts GLFW strings to Dart String for return.
stringToRet() => '  Dart_SetReturnValue(arguments, '
    'HANDLE(Dart_NewStringFromCString(ret)));';

/// A simple left/right String tuple.
class Pair {
  String left;
  String right;

  Pair(this.left, this.right);

  Pair.fromList(List pairs) : this(pairs[0], pairs[1]);

  String toString() => '$left $right'.trim();
}

/// C declaration parser which parses an API function declaration from glfw3.h
/// into its constituent parts.
class CDecl {
  static final ws = new RegExp(r'\s+');
  static final comma = new RegExp(r'\s*,\s+');

  String name;
  String returnType;
  List<Pair> arguments = [];
  String dartReturnType;
  List<Pair> dartArguments = [];

  /// Was this function not easily parsed?
  bool needsManualBinding = false;

  /// Does this function already have a manual binding?
  bool get hasManualBinding => manualBindings.contains(name);

  /// Removes trailing characters from a String.
  static String removeTrailing(String str, int num) =>
      str.substring(0, str.length - num);

  /// Normalizes pointers to sit with the [type].
  ///
  /// Examples:
  ///     (int, *hello) -> (int*, hello)
  ///     (const int, **const*hello) -> (const int**const, hello)
  ///
  /// cdecl.org says the second one means
  ///     "declare hello as const pointer to pointer to const int"
  static List<String> normalizePointer(String type, String name) {
    if (name.startsWith('*')) {
      return normalizePointer('${type}*', name.substring(1));
    } else if (name.startsWith('&')) {
      return normalizePointer('${type}&', name.substring(1));
    } else if (name.startsWith('const*')) {
      return normalizePointer('${type}const*', name.substring(6));
    }
    return [type, name];
  }

  CDecl(String string) {
    var left = (string.split('(')[0].trim().split(ws)..removeLast()).join(" ");
    var right = string.split('(')[0].trim().split(ws).last;
    var norms = normalizePointer(left, right);
    name = norms[1];
    returnType = norms[0];

    for (var arg
        in removeTrailing(string.split('(')[1], 2).trim().split(comma)) {
      right = arg.split(ws).last;
      left = (arg.split(ws)..removeLast()).join(" ");
      arguments.add(new Pair.fromList(normalizePointer(left, right)));
    }

    if (hasManualBinding) {
      return;
    }
    dartReturnType = glfwReturnTypeHintMap[name];
    dartReturnType ??= typeMap[returnType];
    if (dartReturnType == null) {
      needsManualBinding = true;
    }
    dartArguments = arguments.map((pair) {
      if (pair.right == "void") return new Pair("", "void");
      var type = argumentTypeHint['$pair'];
      if (type != null) {
        return new Pair(type, pair.right);
      }
      type = typeMap[pair.left];
      if (type == null) {
        needsManualBinding = true;
        return new Pair(null, null);
      }
      return new Pair(type, pair.right);
    }).toList();
    if (needsManualBinding) {
      print("$name NEEDS MANUAL BINDINGS: $string");
    }
  }

  String get nativeName => '${name}_native';

  String toString() => '$returnType $name(${arguments.join(', ')}); '
      '// $dartArguments -> $dartReturnType'
      '${hasManualBinding ? ' HAS_MANUAL_BINDING' : ''}'
      '${needsManualBinding ? ' NEEDS_MANUAL_BINDING' : ''}';

  /// These functions have manual bindings defined in lib/src/manual_bindings.cc
  static final Set<String> manualBindings = new Set.from([
    "glfwGetVersion",
    "glfwGetMonitors",
    "glfwGetMonitorPos",
    "glfwGetMonitorPhysicalSize",
    "glfwGetVideoModes",
    "glfwGetWindowPos",
    "glfwGetWindowSize",
    "glfwGetFramebufferSize",
    "glfwGetWindowFrameSize",
    "glfwSetWindowUserPointer",
    "glfwGetWindowUserPointer",
    "glfwGetCursorPos",
    "glfwGetJoystickAxes",
    "glfwGetJoystickButtons",
  ]);
}

/// Parses a C const from glfw3.h.
class CConst {
  static final ws = new RegExp(r'\s+');

  String name;
  String value;

  CConst(String string) {
    var norms = string.trim().split(ws);
    name = norms[0];
    value = norms[1];
  }

  String toString() => 'const int $name = $value;';
}

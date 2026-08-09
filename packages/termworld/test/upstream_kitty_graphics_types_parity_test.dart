import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_image.dart';

void main() {
  test('xterm KittyGraphicsTypes 00', () {
    final command = parseKittyCommand('a=T,f=100');
    expect(command.action, 'T');
    expect(command.format, 100);
  });
  test('xterm KittyGraphicsTypes 01', () {
    final command = parseKittyCommand(
      'a=t,f=32,i=5,s=10,v=20,c=3,r=2,m=1,q=2',
    );
    expect(command.action, 't');
    expect(command.format, 32);
    expect(command.id, 5);
    expect(command.width, 10);
    expect(command.height, 20);
    expect(command.columns, 3);
    expect(command.rows, 2);
    expect(command.more, 1);
    expect(command.quiet, 2);
  });
  test('xterm KittyGraphicsTypes 02', () {
    final command = parseKittyCommand('');
    expect(command.action, isNull);
    expect(command.format, isNull);
  });
  test('xterm KittyGraphicsTypes 03', () {
    final command = parseKittyCommand('a=t,f=100');
    expect(command.action, KittyAction.transmit);
    expect(command.format, KittyFormat.png);
  });
  test('xterm KittyGraphicsTypes 04', () {
    final command = parseKittyCommand('a=d,i=5');
    expect(command.action, KittyAction.delete);
    expect(command.id, 5);
  });
  test('xterm KittyGraphicsTypes 05', () {
    final command = parseKittyCommand('a=,f=100');
    expect(command.action, '');
    expect(command.format, 100);
  });
  test('xterm KittyGraphicsTypes 06', () {
    final command = parseKittyCommand('f=100,i=5');
    expect(command.action, isNull);
    expect(command.format, 100);
    expect(command.id, 5);
  });
  test('xterm KittyGraphicsTypes 07', () {
    final command = parseKittyCommand('a=t,f=32,o=z');
    expect(command.action, 't');
    expect(command.format, 32);
    expect(command.compression, 'z');
  });
  test('xterm KittyGraphicsTypes 08', () {
    expect(parseKittyCommand('a=T,f=100,C=1').cursorMovement, 1);
  });
  test('xterm KittyGraphicsTypes 09', () {
    expect(parseKittyCommand('a=T,f=100,C=0').cursorMovement, 0);
  });
  test('xterm KittyGraphicsTypes 10', () {
    final command = parseKittyCommand('a=T,x=10,y=20');
    expect(command.x, 10);
    expect(command.y, 20);
  });
  test('xterm KittyGraphicsTypes 11', () {
    final command = parseKittyCommand('a=t,f=,i=5');
    expect(command.action, 't');
    expect(command.format, isNaN);
    expect(command.id, 5);
  });
  test('xterm KittyGraphicsTypes 12', () {
    expect(parseKittyCommand('a=T,f=100,z=10').zIndex, 10);
  });
  test('xterm KittyGraphicsTypes 13', () {
    expect(parseKittyCommand('a=T,f=100,z=0').zIndex, 0);
  });
  test('xterm KittyGraphicsTypes 14', () {
    expect(parseKittyCommand('a=T,f=100,z=-1').zIndex, -1);
  });
  test('xterm KittyGraphicsTypes 15', () {
    expect(parseKittyCommand('a=T,f=100').zIndex, isNull);
  });
  test('xterm KittyGraphicsTypes 16', () {
    final command = parseKittyCommand('a=d,d=i,i=5');
    expect(command.action, 'd');
    expect(command.deleteSelector, 'i');
    expect(command.id, 5);
  });
  test('xterm KittyGraphicsTypes 17', () {
    expect(parseKittyCommand('a=d,d=A').deleteSelector, 'A');
  });
  test('xterm KittyGraphicsTypes 18', () {
    expect(parseKittyCommand('a=d,d=a').deleteSelector, 'a');
  });
  test('xterm KittyGraphicsTypes 19', () {
    expect(parseKittyCommand('a=d,i=5').deleteSelector, isNull);
  });
  test('xterm KittyGraphicsTypes 20', () {
    final command = parseKittyCommand('a=d,d=i,i=5,p=3');
    expect(command.placementId, 3);
    expect(command.deleteSelector, 'i');
    expect(command.id, 5);
  });
  test('xterm KittyGraphicsTypes 21', () {
    expect(parseKittyCommand('a=d,d=i,i=5').placementId, isNull);
  });
  test('xterm KittyGraphicsTypes 22', () {
    expect(parseKittyCommand('a=t,f=100,I=42').imageNumber, 42);
  });
}

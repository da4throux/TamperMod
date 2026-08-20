import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mod_controller/models/plugin_instance.dart';
import 'package:mod_controller/utils/plugin_category.dart';

void main() {
  group('PluginCategoryHelper classification tests', () {
    test('Correctly identifies Drive / Distortion / Fuzz', () {
      final pedal = PluginInstance(
        instance: '/graph/ts9_drive',
        uri: 'http://moddevices.com/plugins/mod-devel/gx_ts9',
        title: 'TS9 Overdrive',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.drive);
      expect(cat.shortCode, 'DRIVE');
      expect(cat.icon, Icons.bolt);
    });

    test('Correctly identifies Delay & Echo', () {
      final pedal = PluginInstance(
        instance: '/graph/delay_mono',
        uri: 'http://moddevices.com/plugins/mod-devel/bolliedelay',
        title: 'Bollie Delay',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.delay);
      expect(cat.shortCode, 'DELAY');
      expect(cat.icon, Icons.waves);
    });

    test('Correctly identifies Reverb', () {
      final pedal = PluginInstance(
        instance: '/graph/roomy',
        uri: 'http://moddevices.com/plugins/mod-devel/roomy',
        title: 'Roomy Reverb',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.reverb);
      expect(cat.shortCode, 'REVERB');
      expect(cat.icon, Icons.blur_on);
    });

    test('Correctly identifies Modulation & Tremolo', () {
      final pedal = PluginInstance(
        instance: '/graph/tremolo',
        uri: 'http://moddevices.com/plugins/mod-devel/mod-tremolo',
        title: 'Tremolo',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.modulation);
      expect(cat.shortCode, 'MOD');
      expect(cat.icon, Icons.vibration);
    });

    test('Correctly identifies ALO Looper', () {
      final pedal = PluginInstance(
        instance: '/graph/alo',
        uri: 'http://moddevices.com/plugins/mod-devel/alo',
        title: 'ALO Looper',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.looper);
      expect(cat.shortCode, 'LOOPER');
      expect(cat.icon, Icons.loop);
    });

    test('Correctly identifies Switch Box / Routers', () {
      final pedal = PluginInstance(
        instance: '/graph/switch_2way',
        uri: 'http://moddevices.com/plugins/mod-devel/switchbox',
        title: 'SwitchBox 2-Way',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.switcher);
      expect(cat.shortCode, 'SWITCH');
      expect(cat.icon, Icons.alt_route);
    });

    test('Correctly identifies Synth / Generator', () {
      final pedal = PluginInstance(
        instance: '/graph/wgv_gen8sp',
        uri: 'http://moddevices.com/plugins/mod-devel/wgv_gen8sp',
        title: 'WGV GEN8SP',
      );
      final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
      expect(cat.type, PluginCategoryType.pitchSynth);
      expect(cat.shortCode, 'SYNTH');
      expect(cat.icon, Icons.graphic_eq);
    });
  });
}

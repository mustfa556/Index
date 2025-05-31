import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:index/models/subtitle_style.dart';
import 'package:index/utils/preferences.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

class SubtitlesPreferences extends StatefulWidget {
  @override
  _SubtitlesPreferencesState createState() => _SubtitlesPreferencesState();
}

class _SubtitlesPreferencesState extends State<SubtitlesPreferences> {
  Preferences _preferences = Preferences();
  SubtitleStyle? _subtitleStyle;

  navigate({required Widget destination, bool replace = false}) async {
    SwipeablePageRoute pageTransition = SwipeablePageRoute(
      canOnlySwipeFromEdge: true,
      builder: (BuildContext context) => destination,
    );

    if (replace) {
      await Navigator.pushReplacement(
        context,
        pageTransition,
      );
    } else {
      await Navigator.push(
        context,
        pageTransition,
      );
    }
  }

  initSubtitleStyle() async {
    SubtitleStyle subtitleStyle = await _preferences.getSubtitlesStyle();
    setState(() => _subtitleStyle = subtitleStyle);
  }

  @override
  void initState() {
    super.initState();

    initSubtitleStyle();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Subtitles Preferences',
      );
    });
  }

  Text SectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall!.copyWith(
        fontSize: 20,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget VisualPresentation() {
    String subtitle = 'Just like everything else in this place. [Chair scrapes floor]\nThe coordinates point to the old lighthouse.';
    Paint foreground  = Paint()
      ..style = _subtitleStyle!.borderStyle.style
      ..strokeWidth = _subtitleStyle!.borderStyle.strokeWidth
      ..color = SubtitleStyle.colors[_subtitleStyle!.borderStyle.color]!;

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.25,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/subtitles_poster.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      padding: EdgeInsets.all(18),
      child: Center(
        child: Stack(
          children: [
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _subtitleStyle!.fontSize,
                foreground: _subtitleStyle!.hasBorder ? foreground : null,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _subtitleStyle!.fontSize,
                color: SubtitleStyle.colors[_subtitleStyle!.color],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SettingsTile SectionTile({
    required String title,
    required Widget trailing,
    bool enabled = true,
    Function(BuildContext context)? onPressed,
  }) {
    return SettingsTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.displayMedium,
      ),
      leading: null,
      trailing: trailing,
      backgroundColor: Platform.isIOS ? Theme.of(context).cardColor: Colors.transparent,
      onPressed: onPressed,
    );
  }

  SettingsList Customizations() {
    SettingsThemeData settingsThemeData = SettingsThemeData(
      settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
    );

    InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );

    return SettingsList(
      lightTheme: settingsThemeData,
      darkTheme: settingsThemeData,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      sections: [
        SettingsSection(
          title: SectionTitle('Font'),
          tiles: [
            SectionTile(
              title: 'Size',
              trailing: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: DropdownMenu<double>(
                  initialSelection: _subtitleStyle!.fontSize,
                  requestFocusOnTap: false,
                  enableFilter: false,
                  enableSearch: false,
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  inputDecorationTheme: inputDecorationTheme,
                  onSelected: (double? size) async {
                    if (size != null) {
                      setState(() => _subtitleStyle!.fontSize = size);
                      await _preferences.setSubtitlesStyle(_subtitleStyle!);
                    }
                  },
                  dropdownMenuEntries: SubtitleStyle.fontSizes.map<DropdownMenuEntry<double>>((double size) {
                    return DropdownMenuEntry<double>(
                      value: size,
                      label: '${size}'.replaceAll('.0', ''),
                    );
                  }).toList(),
                ),
              ),
            ),
            SectionTile(
              title: 'Color',
              trailing: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: DropdownMenu<String>(
                  initialSelection: _subtitleStyle!.color,
                  requestFocusOnTap: false,
                  enableFilter: false,
                  enableSearch: false,
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  inputDecorationTheme: inputDecorationTheme,
                  onSelected: (String? color) async {
                    if (color != null) {
                      setState(() => _subtitleStyle!.color = color);
                      await _preferences.setSubtitlesStyle(_subtitleStyle!);
                    }
                  },
                  dropdownMenuEntries: SubtitleStyle.colors.keys.map<DropdownMenuEntry<String>>((String color) {
                    return DropdownMenuEntry<String>(
                      value: color,
                      label: color,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: SectionTitle('Border'),
          tiles: [
            SectionTile(
              title: 'Has border',
              trailing: Switch(
                value: _subtitleStyle!.hasBorder,
                onChanged: (isSelected) async {
                  setState(() => _subtitleStyle!.hasBorder = isSelected);
                  await _preferences.setSubtitlesStyle(_subtitleStyle!);
                },
                activeColor: Theme.of(context).primaryColor,
              ),
              onPressed: (context) async {
                setState(() => _subtitleStyle!.hasBorder = !_subtitleStyle!.hasBorder);
                await _preferences.setSubtitlesStyle(_subtitleStyle!);
              },
            ),
            SectionTile(
              title: 'Width',
              enabled: _subtitleStyle!.hasBorder,
              trailing: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: DropdownMenu<double>(
                  initialSelection: _subtitleStyle!.borderStyle.strokeWidth,
                  requestFocusOnTap: false,
                  enableFilter: false,
                  enableSearch: false,
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  inputDecorationTheme: inputDecorationTheme,
                  onSelected: (double? size) async {
                    if (size != null) {
                      setState(() => _subtitleStyle!.borderStyle.strokeWidth = size);
                      await _preferences.setSubtitlesStyle(_subtitleStyle!);
                    }
                  },
                  dropdownMenuEntries: SubtitleStyle.borderWidths.map<DropdownMenuEntry<double>>((double size) {
                    return DropdownMenuEntry<double>(
                      value: size,
                      label: '${size}'.replaceAll('.0', ''),
                    );
                  }).toList(),
                ),
              ),
            ),
            SectionTile(
              title: 'Color',
              enabled: _subtitleStyle!.hasBorder,
              trailing: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: DropdownMenu<String>(
                  initialSelection: _subtitleStyle!.borderStyle.color,
                  requestFocusOnTap: false,
                  enableFilter: false,
                  enableSearch: false,
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  inputDecorationTheme: inputDecorationTheme,
                  onSelected: (String? color) async {
                    if (color != null) {
                      setState(() => _subtitleStyle!.borderStyle.color = color);
                      await _preferences.setSubtitlesStyle(_subtitleStyle!);
                    }
                  },
                  dropdownMenuEntries: SubtitleStyle.colors.keys.map<DropdownMenuEntry<String>>((String color) {
                    return DropdownMenuEntry<String>(
                      value: color,
                      label: color,
                    );
                  }).toList(),
                ),
              ),
            ),
            SectionTile(
              title: 'Style',
              enabled: _subtitleStyle!.hasBorder,
              trailing: Container(
                padding: EdgeInsets.symmetric(vertical: 5),
                child: DropdownMenu<String>(
                  initialSelection: _subtitleStyle!.borderStyle.style.name,
                  requestFocusOnTap: false,
                  enableFilter: false,
                  enableSearch: false,
                  textStyle: Theme.of(context).textTheme.displayLarge,
                  inputDecorationTheme: inputDecorationTheme,
                  onSelected: (String? style) async {
                    if (style != null) {
                      setState(() => _subtitleStyle!.borderStyle.style = PaintingStyle.values.byName(style));
                      await _preferences.setSubtitlesStyle(_subtitleStyle!);
                    }
                  },
                  dropdownMenuEntries: PaintingStyle.values.map((e) => e.name).toList().map<DropdownMenuEntry<String>>((String style) {
                    return DropdownMenuEntry<String>(
                      value: style,
                      label: style.capitalize(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subtitles'),
      ),
      body: _subtitleStyle != null ? SingleChildScrollView(
        child: Column(
          children: [
            VisualPresentation(),
            Customizations(),
          ],
        ),
      ) : Container(),
    );
  }
}

extension StringExtension on String {
  capitalize() {
    if (this.isEmpty) return this;
    return this[0].toUpperCase() + this.substring(1);
  }
}
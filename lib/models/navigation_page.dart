import 'package:flutter/material.dart';
import 'package:index/utils/enums.dart';

class NavigationPage {
  IconData icon;
  String title;
  Widget widget;
  PageType pageType;

  NavigationPage({
    required this.icon,
    required this.title,
    required this.widget,
    required this.pageType,
  });
}

import 'package:flutter/material.dart';
import 'package:signbride/screens/history_screen.dart';
import 'package:signbride/screens/home_screen.dart';
import 'package:signbride/screens/settings_screen.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({super.key});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

int current = 0;
List pages = [HomeScreen(), HistoryScreen(), SettingsScreen()];

class _EditScreenState extends State<EditScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[current],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: current,
        onTap: (index) {
          setState(() {
            current = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 30),
            label: "History",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, size: 30),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}

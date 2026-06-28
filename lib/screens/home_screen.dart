import 'package:flutter/material.dart';
import 'package:signbride/screens/hand_tracker_screen.dart';
import 'package:signbride/widgets/translate_navigator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Color(0xff2DD4BF),
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome again 😊 !',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1E293B),
                        ),
                      ),
                      Text(
                        'We Her to make different conversation',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 50),
              Text(
                'Start \nCommunicating',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1E293B),
                ),
              ),
              SizedBox(height: 30),
              TranslateNavigator(
                text: "Video Model",
                mainColor: Color(0xff5D5FEF),
                secondryColor: Color(0xff7d7ef1),
                nextScreen: HandTrackerScreen(isVideo: true),
              ),
              SizedBox(height: 16),
              TranslateNavigator(
                text: "Picture Model",
                mainColor: Color(0xffFFC857),
                secondryColor: Color(0xffFFD97D),
                nextScreen: HandTrackerScreen(isVideo: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

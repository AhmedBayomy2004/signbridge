import 'package:flutter/material.dart';

class TranslateNavigator extends StatelessWidget {
  const TranslateNavigator({
    super.key,
    required this.text,
    required this.mainColor,
    required this.secondryColor,
    required this.nextScreen,
  });
  final String text;
  final Color mainColor;
  final Color secondryColor;
  final Widget nextScreen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      },
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: mainColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: secondryColor,
              ),
              child: Center(
                child: Image.asset(
                  'assets/icons/video.png',
                  color: Colors.white,
                  height: 40,
                  width: 40,
                ),
              ),
            ),
            SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

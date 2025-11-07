import 'package:flutter/material.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "เพลงตั้งเวลา",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        actionsIconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        elevation: 1,
      ),
      body: Center(child: Text("หน้าการตั้งค่าเพลงตั้งเวลา")),
    );
  }
}

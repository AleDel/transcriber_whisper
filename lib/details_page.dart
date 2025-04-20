import 'package:flutter/material.dart';

class DetailsPage extends StatelessWidget {
  final String audioName; // audioName is now required
  const DetailsPage({super.key, required this.audioName});

  @override
  Widget build(BuildContext context) {
    print("ssssssssssssssss");
    return Scaffold(
      appBar: AppBar(
        title: Text('Details for $audioName'),
      ),
      body: Center(
        child: Text('Details for $audioName'),
      ),
    );
  }
}
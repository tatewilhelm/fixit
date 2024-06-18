import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fixit/login.dart';
import 'package:url_launcher/url_launcher.dart';
import 'parts_page.dart'; // Import the parts page
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  String _shopId = ''; // Initialize to empty

  @override
  void initState() {
    super.initState();
    _fetchShopId();
  }

  void _fetchShopId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('owner', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _shopId = querySnapshot.docs.first.id;
        });
      }
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Login()),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _launchEmail() async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: 't8wilhelm@gmail.com',
      query: 'subject=Bug Report&body=Describe your issue here',
    );
    final url = params.toString();
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FixIt!'),
        backgroundColor: Color(0xFF1D3461), // Dark blue background
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings page (implement the page first)
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1D3461), // Dark blue background
              ),
              child: Text(
                'FixIt!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: Icon(Icons.build),
              title: Text('Repairs'),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: Icon(Icons.settings_applications),
              title: Text('Parts'),
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Old Repairs'),
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('Customers'),
              onTap: () => _onItemTapped(4),
            ),
            ListTile(
              leading: Icon(Icons.description),
              title: Text('Reports'),
              onTap: () => _onItemTapped(5),
            ),
            Spacer(),
            ListTile(
              leading: Icon(Icons.bug_report),
              title: Text('Bug Report'),
              onTap: _launchEmail,
            ),
          ],
        ),
      ),
      body: Center(
        child: _getSelectedPage(),
      ),
    );
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return Text('Welcome to FixIt!', style: TextStyle(fontSize: 24));
      case 1:
        return Text("fuck"); // Use the RepairPage widget
      case 2:
        // Ensure shopId is set before rendering PartsPage
        if (_shopId.isEmpty) {
          return Center(child: CircularProgressIndicator());
        } else {
          return PartsPage(shopId: _shopId); // Use the PartsPage widget and pass the shopId
        }
      case 3:
        return Text('Old Repairs Page', style: TextStyle(fontSize: 24));
      case 4:
        return Text('Customers Page', style: TextStyle(fontSize: 24));
      case 5:
        return Text('Reports Page', style: TextStyle(fontSize: 24));
      default:
        return Text('Welcome to FixIt!', style: TextStyle(fontSize: 24));
    }
  }
}

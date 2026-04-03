import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/alerts_screen.dart';
//veve
void main() {
  runApp(const WeatherAppUI());
}

class WeatherAppUI extends StatefulWidget {
  const WeatherAppUI({super.key});

  @override
  State<WeatherAppUI> createState() {
    return _WeatherAppUIState();
  }
}

class _WeatherAppUIState extends State<WeatherAppUI> {
  AppUser? _currentUser;

  void _handleLogin(AppUser user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _handleLogout() {
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _appTheme,
      home: _currentUser == null
          ? LoginScreen(
              onLogin: _handleLogin,
            )
          : MainShell(
              currentUser: _currentUser!,
              onLogout: _handleLogout,
            ),
    );
  }
}


final ThemeData _appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF4CC9F0),
    secondary: Color(0xFF4361EE),
    surface: Color(0xFF0B1020),
  ),
  scaffoldBackgroundColor: const Color(0xFF050816),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF050816),
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
);


class MainShell extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() {
    return _MainShellState();
  }
}

class _MainShellState extends State<MainShell> {
  int _index = 0;


  @override
  Widget build(BuildContext context) {
final List<Widget> pages = [
      DashboardScreen(currentUser: widget.currentUser),
      const RoutesScreen(), 
      AlertsScreen(currentUser: widget.currentUser), 
    ];
    
    final List<String> titles = ['Pogoda', 'Trasy i Mapy', 'Alerty'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Wyloguj się',
          ),
        ],
      ),
      
      body: SafeArea(
        child: pages[_index],
      ),
      
      
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 70,
        backgroundColor: const Color(0xFF050816),
        indicatorColor: const Color(0xFF1B2640),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Pogoda',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Trasy',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Alerty',
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ridobiko/screens/onboarding/contacts.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/onboarding/notification.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image:
                        AssetImage("assets/onboarding/notification_icon.png"),
                  ),
                ),
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                '“Ridobiko” would like to \nAccess the Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 26,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Allow notifications to stay updated \nwith important alerts and app updates.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: () async {
                    var status = await Permission.notification.status;
                    if (status.isGranted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Contacts()),
                      );
                    } else if (status.isDenied || status.isLimited) {
                      if (await Permission.notification.request().isGranted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Contacts()),
                        );
                      } else if (await Permission
                          .notification.isPermanentlyDenied) {
                        _showPermissionDialog(context);
                      }
                    } else if (status.isPermanentlyDenied) {
                      _showPermissionDialog(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Allow Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8C4747),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notification Permission Required'),
          content: const Text(
            'We need access to notifications to keep you informed with important alerts and updates. '
            'Please enable notification access in the app settings to continue using this feature.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
}

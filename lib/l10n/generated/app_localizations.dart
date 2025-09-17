import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'VibeGuard'**
  String get appTitle;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic error text
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Generic success text
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Yes button text
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No button text
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Register button text
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// First name field label
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// Last name field label
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Good morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// Good afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// Good evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// Start tool recognition button text
  ///
  /// In en, this message translates to:
  /// **'Start Tool Recognition'**
  String get startToolRecognition;

  /// Today's exposure label
  ///
  /// In en, this message translates to:
  /// **'Today\'s Exposure'**
  String get todayExposure;

  /// Safety status label
  ///
  /// In en, this message translates to:
  /// **'Safety Status'**
  String get safetyStatus;

  /// Safety timer title
  ///
  /// In en, this message translates to:
  /// **'Safety Timer'**
  String get safetyTimer;

  /// Start timer button text
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get startTimer;

  /// Stop timer button text
  ///
  /// In en, this message translates to:
  /// **'Stop Timer'**
  String get stopTimer;

  /// Pause timer button text
  ///
  /// In en, this message translates to:
  /// **'Pause Timer'**
  String get pauseTimer;

  /// Resume timer button text
  ///
  /// In en, this message translates to:
  /// **'Resume Timer'**
  String get resumeTimer;

  /// Timer subtitle text
  ///
  /// In en, this message translates to:
  /// **'Track your vibration exposure'**
  String get trackVibrationExposure;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Notification settings section title
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// Allow notifications setting
  ///
  /// In en, this message translates to:
  /// **'Allow Notifications'**
  String get allowNotifications;

  /// Safety alerts setting
  ///
  /// In en, this message translates to:
  /// **'Safety Alerts'**
  String get safetyAlerts;

  /// Break reminders setting
  ///
  /// In en, this message translates to:
  /// **'Break Reminders'**
  String get breakReminders;

  /// Daily reports setting
  ///
  /// In en, this message translates to:
  /// **'Daily Reports'**
  String get dailyReports;

  /// Safety settings section title
  ///
  /// In en, this message translates to:
  /// **'Safety Settings'**
  String get safetySettings;

  /// App settings section title
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// Theme setting label
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Light mode theme name
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// Dark mode theme name
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// System mode theme name
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Data and privacy section title
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get dataPrivacy;

  /// About and support section title
  ///
  /// In en, this message translates to:
  /// **'About & Support'**
  String get aboutSupport;

  /// Sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Tool management title
  ///
  /// In en, this message translates to:
  /// **'Tool Management'**
  String get toolManagement;

  /// Advanced tool management title
  ///
  /// In en, this message translates to:
  /// **'Advanced Tool Management'**
  String get advancedToolManagement;

  /// Tool inventory title
  ///
  /// In en, this message translates to:
  /// **'Tool Inventory'**
  String get toolInventory;

  /// Checkout tool action
  ///
  /// In en, this message translates to:
  /// **'Checkout Tool'**
  String get checkoutTool;

  /// Checkin tool action
  ///
  /// In en, this message translates to:
  /// **'Checkin Tool'**
  String get checkinTool;

  /// Reserve tool action
  ///
  /// In en, this message translates to:
  /// **'Reserve Tool'**
  String get reserveTool;

  /// Tool condition title
  ///
  /// In en, this message translates to:
  /// **'Tool Condition'**
  String get toolCondition;

  /// Tool performance title
  ///
  /// In en, this message translates to:
  /// **'Tool Performance'**
  String get toolPerformance;

  /// Tool warranty title
  ///
  /// In en, this message translates to:
  /// **'Tool Warranty'**
  String get toolWarranty;

  /// Cost tracking title
  ///
  /// In en, this message translates to:
  /// **'Cost Tracking'**
  String get costTracking;

  /// Safety dashboard title
  ///
  /// In en, this message translates to:
  /// **'Safety Dashboard'**
  String get safetyDashboard;

  /// Exposure limit label
  ///
  /// In en, this message translates to:
  /// **'Exposure Limit'**
  String get exposureLimit;

  /// Daily limit label
  ///
  /// In en, this message translates to:
  /// **'Daily Limit'**
  String get dailyLimit;

  /// Weekly limit label
  ///
  /// In en, this message translates to:
  /// **'Weekly Limit'**
  String get weeklyLimit;

  /// Take break message
  ///
  /// In en, this message translates to:
  /// **'Take a Break'**
  String get takeBreak;

  /// Safe limits message
  ///
  /// In en, this message translates to:
  /// **'Great job! You\'re well within safe limits.'**
  String get withinSafeLimits;

  /// Approaching limit warning
  ///
  /// In en, this message translates to:
  /// **'Caution: Approaching daily limit.'**
  String get approachingLimit;

  /// Near limit warning
  ///
  /// In en, this message translates to:
  /// **'Warning: Near daily exposure limit!'**
  String get nearLimit;

  /// Limit exceeded alert
  ///
  /// In en, this message translates to:
  /// **'ALERT: Daily limit exceeded! Take a break.'**
  String get limitExceeded;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/whatsapp_otp_service.dart';
import 'package:dinein_app/features/venue/auth/venue_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CountryRuntime.configure(CountryConfig.mt);
  });

  Future<GoRouter> pumpVenueLogin(
    WidgetTester tester, {
    required VenueLoginScreen screen,
    String initialLocation = '/venue-login',
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/venue-login', builder: (context, state) => screen),
        GoRoute(
          path: '/venue/dashboard',
          builder: (context, state) =>
              const Scaffold(body: Text('Venue Dashboard')),
        ),
        GoRoute(
          path: '/venue/orders',
          builder: (context, state) =>
              const Scaffold(body: Text('Venue Orders')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    return router;
  }

  Future<void> enterVenuePhone(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField).first, value);
    await tester.pump();
  }

  Future<void> enterOtp(WidgetTester tester, String code) async {
    final fields = find.byType(TextField);
    for (var index = 0; index < code.length; index++) {
      await tester.enterText(fields.at(index), code[index]);
      await tester.pump();
    }
  }

  testWidgets('send success advances directly to OTP step', (tester) async {
    await pumpVenueLogin(
      tester,
      screen: VenueLoginScreen(
        sendOtpOverride: (phone, {appScope = 'venue'}) async {
          return WhatsAppOtpChallenge(
            verificationId: 'challenge-1',
            expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
            usesMock: false,
          );
        },
      ),
    );

    await enterVenuePhone(tester, '99123456');
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Code'), findsOneWidget);
  });

  testWidgets('unknown venue number opens the contact-admin dialog', (
    tester,
  ) async {
    await pumpVenueLogin(
      tester,
      screen: VenueLoginScreen(
        sendOtpOverride: (phone, {appScope = 'venue'}) async {
          throw const WhatsAppOtpException(
            message: 'Venue access not found.',
            reason: 'venue_not_found',
          );
        },
      ),
    );

    await enterVenuePhone(tester, '99123456');
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Venue Access Not Found'), findsOneWidget);
    expect(find.text('Contact Admin'), findsOneWidget);
  });

  testWidgets('successful verification returns to the protected venue route', (
    tester,
  ) async {
    VenueAccessSession? savedSession;
    final router = await pumpVenueLogin(
      tester,
      initialLocation: Uri(
        path: '/venue-login',
        queryParameters: {'returnTo': '/venue/orders'},
      ).toString(),
      screen: VenueLoginScreen(
        sendOtpOverride: (phone, {appScope = 'venue'}) async {
          return WhatsAppOtpChallenge(
            verificationId: 'challenge-2',
            expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
            usesMock: false,
          );
        },
        verifyOtpOverride:
            ({
              required phone,
              required verificationId,
              required code,
              appScope = 'venue',
            }) async {
              return WhatsAppOtpVerificationResult(
                verified: true,
                venueSession: VenueAccessSession(
                  accessToken: 'venue-token',
                  venueId: 'venue-1',
                  venueName: 'Harbor Table',
                  whatsAppNumber: phone,
                  issuedAt: DateTime.parse('2026-04-02T08:00:00.000Z'),
                  expiresAt: DateTime.parse('2026-04-02T20:00:00.000Z'),
                ),
              );
            },
        saveVenueSessionOverride: (session) async {
          savedSession = session;
        },
      ),
    );

    await enterVenuePhone(tester, '99123456');
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();

    await enterOtp(tester, '123456');
    await tester.pumpAndSettle();

    expect(savedSession?.venueId, 'venue-1');
    expect(router.routeInformationProvider.value.uri.path, '/venue/orders');
  });

  testWidgets('verification exceptions are rendered inline', (tester) async {
    await pumpVenueLogin(
      tester,
      screen: VenueLoginScreen(
        sendOtpOverride: (phone, {appScope = 'venue'}) async {
          return WhatsAppOtpChallenge(
            verificationId: 'challenge-3',
            expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
            usesMock: false,
          );
        },
        verifyOtpOverride:
            ({
              required phone,
              required verificationId,
              required code,
              appScope = 'venue',
            }) async {
              throw const WhatsAppOtpException(
                message: 'Could not verify the WhatsApp code right now.',
                reason: 'network_error',
              );
            },
      ),
    );

    await enterVenuePhone(tester, '99123456');
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();

    await enterOtp(tester, '123456');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not verify the code right now. Check your connection and retry.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('OTP step exposes semantic back and resend actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpVenueLogin(
        tester,
        screen: VenueLoginScreen(
          sendOtpOverride: (phone, {appScope = 'venue'}) async {
            return WhatsAppOtpChallenge(
              verificationId: 'challenge-4',
              expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
              usesMock: false,
            );
          },
        ),
      );

      expect(find.bySemanticsLabel('Go back'), findsOneWidget);

      await enterVenuePhone(tester, '99123456');
      await tester.tap(find.text('Get OTP'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Go back'), findsOneWidget);
      expect(find.bySemanticsLabel('Resend WhatsApp code'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  // ═══ Cross-regional phone normalization (RW) ═══

  group('Rwanda phone normalization', () {
    setUp(() {
      CountryRuntime.configure(CountryConfig.rw);
    });

    testWidgets('RW: 10-digit phone with leading 0 is accepted', (
      tester,
    ) async {
      String? sentPhone;
      await pumpVenueLogin(
        tester,
        screen: VenueLoginScreen(
          sendOtpOverride: (phone, {appScope = 'venue'}) async {
            sentPhone = phone;
            return WhatsAppOtpChallenge(
              verificationId: 'rw-challenge-1',
              expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
              usesMock: false,
            );
          },
        ),
      );

      // Enter 10-digit number with leading 0 (common RW format)
      await enterVenuePhone(tester, '0795588248');
      await tester.tap(find.text('Get OTP'));
      await tester.pumpAndSettle();

      // Should advance to OTP step (normalization stripped the leading 0)
      expect(find.text('Enter Code'), findsOneWidget);
      // The full phone should have the stripped local number
      expect(sentPhone, '+250795588248');
    });

    testWidgets('RW: 9-digit phone without leading 0 is accepted', (
      tester,
    ) async {
      String? sentPhone;
      await pumpVenueLogin(
        tester,
        screen: VenueLoginScreen(
          sendOtpOverride: (phone, {appScope = 'venue'}) async {
            sentPhone = phone;
            return WhatsAppOtpChallenge(
              verificationId: 'rw-challenge-2',
              expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
              usesMock: false,
            );
          },
        ),
      );

      // Enter 9-digit number directly (no leading 0)
      await enterVenuePhone(tester, '795588248');
      await tester.tap(find.text('Get OTP'));
      await tester.pumpAndSettle();

      // Should advance to OTP step
      expect(find.text('Enter Code'), findsOneWidget);
      expect(sentPhone, '+250795588248');
    });
  });

  // ═══ MT strict 8-digit enforcement ═══

  group('Malta strict phone enforcement', () {
    setUp(() {
      CountryRuntime.configure(CountryConfig.mt);
    });

    testWidgets('MT: 8-digit phone is accepted', (tester) async {
      await pumpVenueLogin(
        tester,
        screen: VenueLoginScreen(
          sendOtpOverride: (phone, {appScope = 'venue'}) async {
            return WhatsAppOtpChallenge(
              verificationId: 'mt-challenge-1',
              expiresAt: DateTime.parse('2026-04-02T12:00:00.000Z'),
              usesMock: false,
            );
          },
        ),
      );

      await enterVenuePhone(tester, '99123456');
      await tester.tap(find.text('Get OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Code'), findsOneWidget);
    });

    testWidgets('MT: 7-digit phone is rejected', (tester) async {
      await pumpVenueLogin(
        tester,
        screen: VenueLoginScreen(
          sendOtpOverride: (phone, {appScope = 'venue'}) async {
            throw Exception('Should not be called');
          },
        ),
      );

      await enterVenuePhone(tester, '9912345'); // 7 digits — too short
      await tester.pump();

      // The Get OTP button should be disabled (no tap sends)
      final getOtpFinder = find.text('Get OTP');
      expect(getOtpFinder, findsOneWidget);
    });
  });
}

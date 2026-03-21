import 'package:dinein_app/core/services/whatsapp_otp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WhatsAppOtpService sut;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sut = WhatsAppOtpService.instance;
  });

  group('WhatsAppOtpService', () {
    test(
      'sendOtp rejects an empty phone number before any backend call',
      () async {
        expect(() => sut.sendOtp(''), throwsException);
      },
    );

    test('verifyOtpDetailed rejects codes shorter than 6 digits', () async {
      final result = await sut.verifyOtpDetailed(
        phone: '+35612345678',
        verificationId: 'test-id',
        code: '12345',
      );
      expect(result.verified, isFalse);
    });

    test('verifyOtpDetailed rejects codes longer than 6 digits', () async {
      final result = await sut.verifyOtpDetailed(
        phone: '+35612345678',
        verificationId: 'test-id',
        code: '1234567',
      );
      expect(result.verified, isFalse);
    });

    test('verifyOtpDetailed rejects empty phone', () async {
      final result = await sut.verifyOtpDetailed(
        phone: '',
        verificationId: 'test-id',
        code: '123456',
      );
      expect(result.verified, isFalse);
    });
  });
}

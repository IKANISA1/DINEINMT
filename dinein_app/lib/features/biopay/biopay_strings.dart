/// Feature-local English / Kinyarwanda copy for BioPay screens.
///
/// The app has no full localization pipeline today, so BioPay uses this
/// module-scoped strings file. When i18n is added later, these move to ARB files.
abstract final class BiopayStrings {
  // ─── Home Screen ───
  static const homeHeadline = 'Register your face. Scan a face. Pay instantly.';
  static const homeBody =
      'BioPay lets Rwanda guests register a face-linked MoMo payment identity '
      'and launch payment from a face scan.';

  // ─── Register Screen ───
  static const registerTitle = 'Register Your Face';
  static const registerSubtitle =
      'Create your BioPay profile by linking your face to your Rwanda MoMo '
      'payment string. No login required.';
  static const registerConsent =
      'I agree that my face embedding (not photo) will be stored securely for '
      'payment matching. I can delete my profile at any time.';
  static const registerConsentKw =
      'Nemera ko ifoto yanjye yoherezwa mu buryo bwizewe cyane kugirango '
      'mpemure. Nshobora gusiba konti yanjye igihe cyose.';

  // ─── Scanner Screen ───
  static const scanTitle = 'Scan To Pay';
  static const scanSubtitle =
      'Point your camera at the payee\u2019s face to match their payment profile.';
  static const scanSearching = 'Looking for a face\u2026';
  static const scanLocked = 'Face locked — hold steady';
  static const scanNoMatch = 'No match found. Try again.';
  static const scanError = 'Scanner error. Please try again.';

  // ─── Confirm Screen ───
  static const confirmTitle = 'Confirm Payment';
  static const confirmSubtitle =
      'Verify the matched profile below, then launch MoMo to complete payment.';
  static const confirmPayCta = 'PAY WITH MOMO';
  static const confirmNotMe = 'NOT ME — REPORT';

  // ─── Manage Screen ───
  static const manageTitle = 'Manage Your Profile';
  static const manageSubtitle =
      'Update your display name, payment string, re-enroll your face, '
      'or delete your BioPay profile.';
  static const manageReEnroll = 'RE-ENROLL FACE';
  static const manageDelete = 'DELETE PROFILE';
  static const manageReport = 'REPORT ABUSE';

  // ─── Quality Feedback ───
  static const qualityLowLight = 'Move to a brighter area';
  static const qualityFaceTooSmall = 'Move closer to the camera';
  static const qualityMultipleFaces = 'Only one face should be visible';
  static const qualityYawTooHigh = 'Face the camera directly';
  static const qualityEyesClosed = 'Please open your eyes';

  // ─── Management Code ───
  static const managementCodeTitle = 'Your Management Code';
  static const managementCodeBody =
      'Save this code securely. You\u2019ll need it to manage your profile '
      'from another device. This code is shown only once.';
}

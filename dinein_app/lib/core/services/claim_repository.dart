import '../constants/enums.dart';
import '../models/models.dart';
import 'dinein_api_service.dart';

/// Repository for venue claim operations via Supabase.
class ClaimRepository {
  ClaimRepository._();
  static final instance = ClaimRepository._();

  /// Submit a new venue claim for admin review.
  Future<VenueClaim> submitClaim({
    required String venueId,
    required String venueName,
    required String venueArea,
    String? contactPhone,
    String? email,
    String? pin,
    String? claimantName,
    String? claimantId,
  }) async {
    final contactValue = contactPhone ?? email;
    if (contactValue == null || contactValue.trim().isEmpty) {
      throw ArgumentError('contactPhone or email is required');
    }

    final normalizedContact = _normalizeContact(contactValue);
    final normalizedEmail = email != null && email.trim().isNotEmpty
        ? email.trim()
        : null;
    final normalizedPhone =
        contactPhone != null && contactPhone.trim().isNotEmpty
        ? normalizedContact
        : null;

    final data = await DineinApiService.invoke(
      'submit_claim',
      payload: {
        'venueId': venueId,
        'venueName': venueName,
        'venueArea': venueArea,
        ...?switch (normalizedPhone) {
          String value => {'contactPhone': value},
          _ => null,
        },
        ...?switch (normalizedEmail) {
          String value => {'email': value},
          _ => null,
        },
        'pin': pin,
        'claimantName': claimantName,
        'claimantId': claimantId,
      },
    );
    return VenueClaim.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch all pending claims (admin view).
  Future<List<VenueClaim>> getPendingClaims() async {
    final data =
        await DineinApiService.invoke(
              'get_pending_claims',
              useAdminSession: true,
            )
            as List<dynamic>;
    return data.map((e) => VenueClaim.fromJson(e)).toList();
  }

  /// Resolve the most recent claim for a WhatsApp number.
  Future<VenueClaim?> getLatestClaimByContact(
    String contactPhone, {
    ClaimStatus? status,
  }) async {
    final normalizedPhone = _normalizeContact(contactPhone);
    final data = await DineinApiService.invoke(
      'get_latest_claim_by_contact',
      payload: {
        'contactPhone': normalizedPhone,
        if (status != null) 'status': status.dbValue,
      },
    );
    return data != null
        ? VenueClaim.fromJson(data as Map<String, dynamic>)
        : null;
  }

  /// Approve a claim — sets claim status to approved and assigns venue owner.
  Future<Map<String, dynamic>> approveClaim(
    String claimId,
    String venueId, [
    String? legacyContact,
  ]) async {
    final normalizedLegacyContact = legacyContact?.trim();
    final data = await DineinApiService.invoke(
      'approve_claim',
      useAdminSession: true,
      payload: {
        'claimId': claimId,
        'venueId': venueId,
        ...?switch (normalizedLegacyContact) {
          String value when value.isNotEmpty => {'legacyContact': value},
          _ => null,
        },
      },
    );
    return (data as Map<String, dynamic>?) ?? const {};
  }

  /// Admin-only helper to approve a claim and issue a venue token.
  Future<Map<String, dynamic>> autoApproveOnboardingClaim({
    required String claimId,
    required String venueId,
    String? contactPhone,
  }) async {
    final data = await DineinApiService.invoke(
      'auto_approve_onboarding_claim',
      useAdminSession: true,
      payload: {
        'claimId': claimId,
        'venueId': venueId,
        // ignore: use_null_aware_elements
        if (contactPhone != null) 'contactPhone': contactPhone,
      },
    );
    return data as Map<String, dynamic>;
  }

  /// Reject a claim.
  Future<void> rejectClaim(String claimId) async {
    await DineinApiService.invoke(
      'reject_claim',
      useAdminSession: true,
      payload: {'claimId': claimId},
    );
  }

  String _normalizeContact(String value) {
    final trimmed = value.trim();
    final startsWithPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return trimmed;
    return startsWithPlus ? '+$digits' : digits;
  }
}

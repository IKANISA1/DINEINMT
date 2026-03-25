import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/config/country_runtime.dart';
import '../../../core/constants/enums.dart';

import '../../../core/providers/permission_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/models/models.dart';
import '../../../core/models/onboarding_draft_models.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/claim_repository.dart';
import '../../../core/services/onboarding_draft_service.dart';
import '../../../core/services/venue_repository.dart';
import '../../../core/services/menu_repository.dart';
import '../../../core/services/whatsapp_otp_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

// ─── FLOW PHASES ───
enum _Phase { step1, building, step2, step3, step4 }

enum _Step2MenuAction { photo, upload, manual }

class VenueOnboardingFlow extends ConsumerStatefulWidget {
  const VenueOnboardingFlow({super.key});
  @override
  ConsumerState<VenueOnboardingFlow> createState() =>
      _VenueOnboardingFlowState();
}

class _VenueOnboardingFlowState extends ConsumerState<VenueOnboardingFlow>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.step1;

  // Step 1
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _venueResults = [];
  bool _isSearching = false;
  bool _isSearchingGoogleMaps = false;
  bool _hasSearchedWithNoResults = false;
  String _lastSearchQuery = '';
  OnboardingVenueSearchBlock? _blockedVenueMatch;
  List<Map<String, dynamic>> _featuredVenues = [];
  bool _isFeaturedLoading = true;
  bool _showingGoogleMapsResults = false;
  String? _step1Notice;
  bool _step1NoticeIsError = false;
  Timer? _debounce;

  // Building loader
  late AnimationController _buildProgressCtrl;
  int _buildStatusIndex = 0;
  static const _buildStatuses = [
    'INFERRING IDENTITY…',
    'ENRICHING MAPS DATA…',
    'AUTO-BUILDING MENU…',
  ];

  // Step 2 / 3
  ClaimedVenueDraft? _claimedVenue;
  List<OcrDraftMenuItem> _draftItems = [];
  bool _isProcessingOcr = false;
  String _ocrStatusMessage = 'UPLOADING FILE…';
  String? _onboardingMenuToken;
  bool _returnToMenuAfterVerification = false;
  _Step2MenuAction? _selectedMenuAction;

  // Step 4
  final _phoneCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  String _otpStep = 'phone'; // phone | otp | submitted
  bool _isLoading = false;
  String? _error;
  String? _info;
  WhatsAppOtpChallenge? _challenge;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _buildProgressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _loadExistingDraft();
    _loadFeaturedVenues();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _buildProgressCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingDraft() async {
    final venue = await OnboardingDraftService.loadClaimedVenue();
    final items = await OnboardingDraftService.loadMenuDraftItems();
    final onboardingMenuToken =
        await OnboardingDraftService.loadOnboardingMenuToken();
    if (!mounted) return;
    setState(() {
      _claimedVenue = venue;
      _draftItems = items;
      _onboardingMenuToken = onboardingMenuToken;
    });
  }

  Future<void> _loadFeaturedVenues() async {
    try {
      final venues = await VenueRepository.instance.getClaimableVenues(
        limit: 6,
      );
      if (!mounted) return;
      setState(() {
        _featuredVenues = venues
            .map(
              (v) => {
                'id': v.id,
                'name': v.name,
                'address': v.address,
                'category': v.category,
                'rating': v.rating,
                'slug': v.slug,
                'image_url': v.imageUrl,
              },
            )
            .toList();
        _isFeaturedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFeaturedLoading = false);
    }
  }

  // ─── STEP INDICES ───
  int get _stepNumber {
    switch (_phase) {
      case _Phase.step1:
      case _Phase.building:
        return 1;
      case _Phase.step2:
        return 2;
      case _Phase.step3:
        return 3;
      case _Phase.step4:
        return 4;
    }
  }

  String get _stepTitle {
    switch (_phase) {
      case _Phase.step1:
        return 'Add Your Venue';
      case _Phase.building:
        return 'Building Venue…';
      case _Phase.step2:
        return 'Complete Your Profile';
      case _Phase.step3:
        return 'Review Menu';
      case _Phase.step4:
        if (_hasVerifiedMenuAccess) return 'Submit Claim';
        return _otpStep == 'phone' ? 'Activate Venue' : 'Verify Identity';
    }
  }

  bool get _showStepHeader => _phase != _Phase.building;
  bool get _hasVerifiedMenuAccess =>
      (_onboardingMenuToken?.isNotEmpty ?? false) &&
      (_claimedVenue?.contactPhone?.isNotEmpty ?? false);

  String? get _verifiedContactPhone => _claimedVenue?.contactPhone;

  // ─── NAVIGATION ───
  void _goBack() {
    switch (_phase) {
      case _Phase.step1:
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.goNamed(AppRouteNames.guestSettings);
        }
        return;
      case _Phase.building:
        setState(() => _phase = _Phase.step1);
        return;
      case _Phase.step2:
        setState(() => _phase = _Phase.step1);
        return;
      case _Phase.step3:
        setState(() => _phase = _Phase.step2);
        return;
      case _Phase.step4:
        if (_otpStep == 'otp') {
          setState(() {
            _otpStep = 'phone';
            _error = null;
          });
        } else {
          setState(() {
            _phase = _returnToMenuAfterVerification
                ? _Phase.step2
                : _Phase.step3;
            _returnToMenuAfterVerification = false;
            _info = null;
          });
        }
        return;
    }
  }

  // ─── SEARCH (Step 1) ───
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _venueResults = [];
        _isSearching = false;
        _isSearchingGoogleMaps = false;
        _hasSearchedWithNoResults = false;
        _blockedVenueMatch = null;
        _showingGoogleMapsResults = false;
        _step1Notice = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _showingGoogleMapsResults = false;
      _step1Notice = null;
      _blockedVenueMatch = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchVenues(query.trim()),
    );
  }

  Future<void> _searchVenues(String query) async {
    try {
      final search = await VenueRepository.instance.searchOnboardingVenues(
        query,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _venueResults = search.venues
            .map(
              (v) => {
                'id': v.id,
                'name': v.name,
                'address': v.address,
                'category': v.category,
                'rating': v.rating,
                'slug': v.slug,
              },
            )
            .toList();
        _isSearching = false;
        _hasSearchedWithNoResults =
            search.venues.isEmpty && search.blockedMatch == null;
        _blockedVenueMatch = search.blockedMatch;
        _lastSearchQuery = query;
        _showingGoogleMapsResults = false;
        _step1Notice = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _blockedVenueMatch = null;
        _showingGoogleMapsResults = false;
        _step1Notice = 'Primary venue search failed. Please retry.';
        _step1NoticeIsError = true;
      });
    }
  }

  Future<void> _searchGoogleMaps() async {
    final query = _lastSearchQuery.trim().isNotEmpty
        ? _lastSearchQuery.trim()
        : _searchCtrl.text.trim();
    if (query.length < 2) return;

    setState(() {
      _isSearchingGoogleMaps = true;
      _step1Notice = null;
      _step1NoticeIsError = false;
      _blockedVenueMatch = null;
    });

    try {
      final results = await VenueRepository.instance.searchGoogleMaps(query);
      if (!mounted) return;
      setState(() {
        _venueResults = results
            .map(
              (venue) => <String, dynamic>{
                'id': null,
                'source': 'google_maps',
                'name': venue['name'] as String? ?? '',
                'address': venue['address'] as String? ?? '',
                'category': venue['category'] as String? ?? 'Restaurants',
                'rating': venue['rating'],
                'ratingCount': venue['ratingCount'],
                'image_url': venue['image_url'],
                'phone': venue['phone'],
                'website_url': venue['website'],
                'place_id': venue['placeId'],
              },
            )
            .toList(growable: false);
        _isSearchingGoogleMaps = false;
        _showingGoogleMapsResults = true;
        _hasSearchedWithNoResults = _venueResults.isEmpty;
        _step1Notice = _venueResults.isEmpty
            ? 'No Google Maps matches were found for "$query".'
            : 'Showing grounded Google Maps matches for "$query".';
        _step1NoticeIsError = _venueResults.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearchingGoogleMaps = false;
        _showingGoogleMapsResults = false;
        _step1Notice =
            'Google Maps search is currently unavailable. You can still continue with direct menu upload.';
        _step1NoticeIsError = true;
      });
    }
  }

  Future<void> _selectVenue(Map<String, dynamic> venue) async {
    final draft = ClaimedVenueDraft(
      venueId: venue['id'] as String?,
      name: venue['name'] as String? ?? '',
      address: venue['address'] as String? ?? '',
      category: venue['category'] as String? ?? 'Restaurants',
      description: '',
      imageUrl: venue['image_url'] as String?,
      contactPhone: venue['phone'] as String?,
      websiteUrl: venue['website_url'] as String?,
    );
    await OnboardingDraftService.saveClaimedVenue(draft);
    if (!mounted) return;
    setState(() {
      _claimedVenue = draft;
      _phase = _Phase.building;
      _selectedMenuAction = null;
    });
    _runBuildingAnimation();
  }

  // ─── BUILDING LOADER ───
  Future<void> _runBuildingAnimation() async {
    _buildProgressCtrl.reset();
    setState(() => _buildStatusIndex = 0);
    _buildProgressCtrl.forward();

    for (var i = 1; i < _buildStatuses.length; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _buildStatusIndex = i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Start with empty menu — user adds items manually in Step 3
    if (_draftItems.isEmpty) {
      await OnboardingDraftService.saveMenuDraftItems(const []);
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.step2);
  }

  // ─── STEP 2 ACTIONS ───
  bool _ensureMenuUploadAccess() {
    if (_hasVerifiedMenuAccess) return true;
    setState(() {
      _phase = _Phase.step4;
      _otpStep = 'phone';
      _returnToMenuAfterVerification = true;
      _error = null;
      _info = 'Verify your WhatsApp number to unlock menu scanning.';
    });
    return false;
  }

  Future<void> _takePhoto() async {
    if (!_ensureMenuUploadAccess()) return;
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.venueCamera(),
    );
    if (!mounted || action != PermissionAccessDialogAction.grantAccess) return;

    final hasCameraAccess = await ref
        .read(appPermissionServiceProvider)
        .ensureVenueCameraAccess();
    if (!hasCameraAccess || !mounted) {
      if (!hasCameraAccess) {
        setState(() {
          _isProcessingOcr = false;
          _error = 'Camera access is required to take a photo.';
        });
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      await _processMenuFile(image.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _error = 'Camera access failed. Please check permissions.';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (!_ensureMenuUploadAccess()) return;
    final action = await PermissionAccessDialog.show(
      context,
      config: PermissionAccessDialogConfig.venuePhotos(),
    );
    if (!mounted || action != PermissionAccessDialogAction.grantAccess) return;

    final hasPhotoAccess = await ref
        .read(appPermissionServiceProvider)
        .ensureVenuePhotoAccess();
    if (!hasPhotoAccess || !mounted) {
      if (!hasPhotoAccess) {
        setState(() {
          _isProcessingOcr = false;
          _error = 'Photo library access is required to upload menu images.';
        });
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
      );
      if (result == null || result.files.single.path == null || !mounted) {
        return;
      }
      await _processMenuFile(result.files.single.path!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _error = 'File selection failed. Check photo access and try again.';
      });
    }
  }

  Future<void> _processMenuFile(String filePath) async {
    setState(() {
      _isProcessingOcr = true;
      _ocrStatusMessage = 'UPLOADING FILE…';
      _error = null;
    });

    try {
      // Upload to Supabase Storage
      final fileUrl = await MenuRepository.instance.uploadMenuFile(
        filePath,
        onboardingMenuToken: _onboardingMenuToken,
      );
      if (!mounted) return;
      setState(() => _ocrStatusMessage = 'EXTRACTING MENU…');

      // OCR extraction via Gemini
      final items = await MenuRepository.instance.extractMenuFromFile(
        fileUrl,
        onboardingMenuToken: _onboardingMenuToken,
      );
      if (!mounted) return;
      setState(() => _ocrStatusMessage = 'BUILDING DRAFT…');

      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Save extracted items as draft
      _draftItems = items;
      await OnboardingDraftService.saveMenuDraftItems(_draftItems);
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _phase = _Phase.step3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _error =
            'Menu extraction failed. Please try again or add items manually.';
      });
    }
  }

  Future<void> _skipMenuUpload() async {
    // If venue has an ID, fetch existing menu items
    if (_claimedVenue?.venueId != null) {
      setState(() {
        _isProcessingOcr = true;
        _ocrStatusMessage = 'LOADING EXISTING MENU…';
      });
      try {
        final existingItems = await MenuRepository.instance.getMenuItems(
          _claimedVenue!.venueId!,
        );
        if (!mounted) return;
        _draftItems = existingItems
            .map(
              (item) => OcrDraftMenuItem(
                name: item.name,
                description: item.description,
                price: item.price,
                category: item.category,
                tags: item.tags,
                requiresReview: false,
              ),
            )
            .toList();
        await OnboardingDraftService.saveMenuDraftItems(_draftItems);
      } catch (_) {
        // If fetch fails, proceed with empty menu
      }
    }
    if (!mounted) return;
    setState(() {
      _isProcessingOcr = false;
      _phase = _Phase.step3;
    });
  }

  void _addManually() {
    // Proceed to Step 3 with empty (or existing) menu
    setState(() => _phase = _Phase.step3);
  }

  Future<void> _submitSelectedMenuAction() async {
    final action = _selectedMenuAction ?? _Step2MenuAction.manual;
    switch (action) {
      case _Step2MenuAction.photo:
        return _takePhoto();
      case _Step2MenuAction.upload:
        return _uploadFile();
      case _Step2MenuAction.manual:
        _addManually();
        return;
    }
  }

  // ─── STEP 3 ACTIONS ───
  void _approveAll() {
    setState(() {
      _draftItems = _draftItems
          .map((item) => item.copyWith(requiresReview: false))
          .toList();
    });
    OnboardingDraftService.saveMenuDraftItems(_draftItems);
  }

  void _deleteItem(int index) {
    setState(() => _draftItems.removeAt(index));
    OnboardingDraftService.saveMenuDraftItems(_draftItems);
  }

  void _showAddItemDialog() {
    _showItemEditorSheet();
  }

  void _showEditItemDialog(int index) {
    _showItemEditorSheet(index: index);
  }

  void _showItemEditorSheet({int? index}) {
    final existing = index != null ? _draftItems[index] : null;
    final nameCtrl = TextEditingController(text: existing?.name ?? 'New Item');
    final priceCtrl = TextEditingController(
      text: existing == null ? '0' : existing.price.toStringAsFixed(2),
    );
    final catCtrl = TextEditingController(
      text: existing?.category ?? 'General',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
            left: AppTheme.space4,
            right: AppTheme.space4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space4,
          ),
          child: _OnboardingPanel(
            radius: 32,
            padding: const EdgeInsets.all(AppTheme.space8),
            backgroundColor: cs.surfaceContainerLow,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  index == null ? 'ADD ITEM' : 'EDIT ITEM',
                  style: tt.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  'Refine your menu details.',
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppTheme.space6),
                _EditorFieldLabel(label: 'Item Name'),
                const SizedBox(height: AppTheme.space2),
                _OnboardingTextField(
                  controller: nameCtrl,
                  hintText: 'New Item',
                ),
                const SizedBox(height: AppTheme.space5),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditorFieldLabel(label: 'Price (€)'),
                          const SizedBox(height: AppTheme.space2),
                          _OnboardingTextField(
                            controller: priceCtrl,
                            hintText: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditorFieldLabel(label: 'Category'),
                          const SizedBox(height: AppTheme.space2),
                          _OnboardingTextField(
                            controller: catCtrl,
                            hintText: 'General',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space6),
                Row(
                  children: [
                    Expanded(
                      child: _SheetActionButton(
                        label: 'Cancel',
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: _SheetActionButton(
                        label: 'Save',
                        emphasized: true,
                        onTap: () {
                          final name = nameCtrl.text.trim();
                          final price =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          final category = catCtrl.text.trim().isEmpty
                              ? 'General'
                              : catCtrl.text.trim();
                          if (name.isEmpty) return;
                          setState(() {
                            final nextItem = OcrDraftMenuItem(
                              name: name,
                              description: existing?.description ?? '',
                              price: price,
                              category: category,
                              tags: existing?.tags ?? const [],
                              requiresReview: false,
                            );
                            if (index == null) {
                              _draftItems.add(nextItem);
                            } else {
                              _draftItems[index] = nextItem;
                            }
                          });
                          OnboardingDraftService.saveMenuDraftItems(
                            _draftItems,
                          );
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── STEP 4: OTP ───
  String get _countryCode => CountryRuntime.config.defaultCountryCode;
  int get _expectedPhoneLength =>
      CountryRuntime.config.country == Country.rw ? 10 : 8;
  String get _localPhone => normalizePhoneLocalInput(
    _phoneCtrl.text,
    countryCode: _countryCode,
    maxDigits: _expectedPhoneLength,
  );

  String get _normalizedPhone {
    final local = _localPhone;
    if (local.isEmpty) return '';
    return '${CountryRuntime.config.countryDialCode}$local';
  }

  bool get _canSendOtp =>
      !_isLoading &&
      isValidPhoneLocalInput(
        _phoneCtrl.text,
        countryCode: _countryCode,
        expectedLength: _expectedPhoneLength,
      );

  Future<void> _sendOtp() async {
    if (!_canSendOtp) {
      setState(() {
        _error =
            'Enter your $_expectedPhoneLength-digit ${CountryRuntime.config.country.label} phone number.';
      });
      return;
    }

    final phone = _normalizedPhone;
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      final challenge = await WhatsAppOtpService.instance.sendOtp(
        phone,
        appScope: 'onboarding',
      );
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _otpStep = 'otp';
        _isLoading = false;
        _info =
            !kReleaseMode && challenge.usesMock && challenge.debugCode != null
            ? 'Dev code: ${challenge.debugCode}'
            : 'Code sent to $phone';
        _resendSeconds = 45;
      });
      _startResendTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not send code. Check number and retry.';
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _verifyAndSubmit() async {
    final challenge = _challenge;
    final code = _otpCtrls.map((c) => c.text).join();
    if (challenge == null || code.length != 6) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Use verifyOtpDetailed to get venue session data
    final result = await WhatsAppOtpService.instance.verifyOtpDetailed(
      phone: _normalizedPhone,
      verificationId: challenge.verificationId,
      code: code,
      appScope: 'onboarding',
    );
    if (!result.verified) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Invalid code. Request a fresh one.';
      });
      return;
    }

    await _storeVerifiedOnboardingAccess(
      phone: _normalizedPhone,
      onboardingMenuToken: result.onboardingMenuToken,
    );

    if (_returnToMenuAfterVerification) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _phase = _Phase.step2;
        _otpStep = 'phone';
        _returnToMenuAfterVerification = false;
        _challenge = null;
        _error = null;
        _info = 'Identity verified. Menu scanning is now unlocked.';
      });
      return;
    }

    await _completeClaimSubmission(
      verifiedPhone: _normalizedPhone,
      venueSession: result.venueSession,
    );
  }

  Future<void> _submitClaimWithVerifiedPhone() async {
    final verifiedPhone = _verifiedContactPhone;
    if (verifiedPhone == null || verifiedPhone.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Verify your WhatsApp number before submitting the claim.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _completeClaimSubmission(verifiedPhone: verifiedPhone);
  }

  Future<void> _storeVerifiedOnboardingAccess({
    required String phone,
    String? onboardingMenuToken,
  }) async {
    final claimedVenue =
        _claimedVenue ?? await OnboardingDraftService.loadClaimedVenue();
    if (claimedVenue == null) {
      return;
    }

    final persistedVenue = claimedVenue.copyWith(contactPhone: phone);
    await OnboardingDraftService.saveClaimedVenue(persistedVenue);
    if (onboardingMenuToken != null && onboardingMenuToken.isNotEmpty) {
      await OnboardingDraftService.saveOnboardingMenuToken(onboardingMenuToken);
    }
    if (!mounted) return;
    setState(() {
      _claimedVenue = persistedVenue;
      _onboardingMenuToken = onboardingMenuToken ?? _onboardingMenuToken;
    });
  }

  Future<void> _completeClaimSubmission({
    required String verifiedPhone,
    VenueAccessSession? venueSession,
  }) async {
    final claimedVenue =
        _claimedVenue ?? await OnboardingDraftService.loadClaimedVenue();
    if (claimedVenue == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Venue data missing. Start over.';
      });
      return;
    }

    // Create the venue record if it doesn't exist
    ClaimedVenueDraft resolved;
    try {
      resolved = await _ensureVenueRecord(claimedVenue);
    } catch (e) {
      final message = _errorMessageFrom(e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = message ?? 'Could not register venue. Please try again.';
      });
      return;
    }

    // Submit claim for admin review.
    try {
      await ClaimRepository.instance.submitClaim(
        venueId: resolved.venueId!,
        venueName: resolved.name,
        venueArea: resolved.address,
        contactPhone: verifiedPhone,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not submit your claim. Please try again.';
      });
      return;
    }

    final persisted = resolved.copyWith(
      contactPhone: verifiedPhone,
      claimSubmitted: true,
    );
    await OnboardingDraftService.saveClaimedVenue(persisted);

    final matchedVenueSession =
        venueSession != null && venueSession.venueId == resolved.venueId
        ? venueSession
        : null;
    if (matchedVenueSession != null) {
      await AuthRepository.instance.saveVenueSession(matchedVenueSession);
      if (_draftItems.isNotEmpty) {
        try {
          await MenuRepository.instance.importDraftItems(
            resolved.venueId!,
            _draftItems,
          );
        } catch (_) {
          // Menu import failure should not block onboarding.
        }
      }
      if (!mounted) return;
      await OnboardingDraftService.clearOnboardingMenuToken();
      if (!mounted) return;
      context.goNamed(AppRouteNames.venueDashboard);
      return;
    }

    if (_draftItems.isNotEmpty) {
      try {
        await OnboardingDraftService.saveMenuDraftItems(_draftItems);
      } catch (_) {
        // Draft persistence failure should not override claim submission.
      }
    }

    await OnboardingDraftService.clearOnboardingMenuToken();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _otpStep = 'submitted';
      _onboardingMenuToken = null;
      _error = null;
      _info = 'Your claim was submitted and is pending admin review.';
    });
  }

  Future<ClaimedVenueDraft> _ensureVenueRecord(ClaimedVenueDraft draft) async {
    if (draft.venueId != null) return draft;
    final normalizedContact = _normalizedPhone;
    final submissionDraft = normalizedContact.isEmpty
        ? draft
        : draft.copyWith(contactPhone: normalizedContact);
    final venue = await VenueRepository.instance.createPendingClaimVenue(
      submissionDraft,
    );
    final persisted = submissionDraft.copyWith(venueId: venue.id);
    await OnboardingDraftService.saveClaimedVenue(persisted);
    return persisted;
  }

  String? _errorMessageFrom(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final message = raw.trim();
    return message.isEmpty ? null : message;
  }

  String _blockedVenueTitle(OnboardingVenueSearchBlock match) {
    switch (match.reason) {
      case 'already_live':
        return 'Already Live';
      case 'already_onboarding':
        return 'Already In Review';
      default:
        return 'Unavailable';
    }
  }

  String _blockedVenueCardHeading(OnboardingVenueSearchBlock match) {
    switch (match.reason) {
      case 'already_live':
        return 'VENUE\nALREADY\nLIVE';
      case 'already_onboarding':
        return 'CLAIM\nALREADY\nSTARTED';
      default:
        return 'VENUE\nUNAVAILABLE';
    }
  }

  String _blockedVenueMessage(OnboardingVenueSearchBlock match) {
    switch (match.reason) {
      case 'already_live':
        return '${match.name} is already live on DineIn and has been claimed, so it is hidden from onboarding search.';
      case 'already_onboarding':
        return '${match.name} already has an onboarding or activation flow in progress, so a new onboarding entry cannot be created.';
      default:
        return '${match.name} is not available for onboarding from this search.';
    }
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_phase == _Phase.building) return _buildLoadingScreen(cs, tt);
    if (_otpStep == 'submitted' && _phase == _Phase.step4) {
      return _buildSubmittedScreen(cs, tt);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─ Header ─
              if (_showStepHeader) ...[
                _BackButton(onTap: _goBack),
                const SizedBox(height: AppTheme.space5),
                Text(
                  _phase == _Phase.step2
                      ? 'STEP $_stepNumber OF 4 • OPTIONAL'
                      : _phase == _Phase.step4
                      ? 'STEP $_stepNumber OF 4 • FINAL STEP'
                      : 'STEP $_stepNumber OF 4',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                if (_phase == _Phase.step1) ...[
                  // Custom two-line title for Step 1
                  Text(
                    'ADD YOUR',
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    'VENUE',
                    style: GoogleFonts.publicSans(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: cs.primary,
                      height: 1.1,
                    ),
                  ),
                ] else ...[
                  Text(
                    _stepTitle.toUpperCase(),
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space6),
              ],
              // ─ Content ─
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildContent(cs, tt),
                ),
              ),
              // ─ Bottom button ─
              if (_phase != _Phase.step4) ...[_buildBottomButton(cs, tt)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, TextTheme tt) {
    switch (_phase) {
      case _Phase.step1:
        return _buildStep1(cs, tt);
      case _Phase.step2:
        return _buildStep2(cs, tt);
      case _Phase.step3:
        return _buildStep3(cs, tt);
      case _Phase.step4:
        return _buildStep4(cs, tt);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButton(ColorScheme cs, TextTheme tt) {
    switch (_phase) {
      case _Phase.step2:
        return _isProcessingOcr
            ? const SizedBox.shrink()
            : Column(
                children: [
                  _OnboardingPrimaryButton(
                    label: 'Submit',
                    icon: LucideIcons.arrowRight,
                    onPressed: _submitSelectedMenuAction,
                  ),
                  const SizedBox(height: AppTheme.space3),
                  Center(
                    child: TextButton(
                      onPressed: _skipMenuUpload,
                      child: Text(
                        'SKIP FOR NOW',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
      case _Phase.step3:
        return Column(
          children: [
            _OnboardingPrimaryButton(
              label: 'Submit Menu',
              icon: LucideIcons.arrowRight,
              onPressed: () => setState(() => _phase = _Phase.step4),
            ),
            const SizedBox(height: AppTheme.space3),
            Center(
              child: Text(
                'YOU CAN ALWAYS EDIT THESE LATER IN MENU MANAGER',
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  letterSpacing: 1,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══ STEP 1: ADD YOUR VENUE ═══
  Widget _buildStep1(ColorScheme cs, TextTheme tt) {
    final hasText = _searchCtrl.text.trim().isNotEmpty;
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar — pill with icon, clear button, gold border on input
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
              border: Border.all(
                color: hasText
                    ? cs.primary.withValues(alpha: 0.45)
                    : cs.outlineVariant.withValues(alpha: 0.10),
                width: hasText ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    LucideIcons.search,
                    color: hasText
                        ? cs.primary.withValues(alpha: 0.7)
                        : cs.onSurfaceVariant.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _onSearchChanged(v);
                      setState(() {});
                    },
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search venue name...',
                      hintStyle: tt.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (hasText)
                  PressableScale(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() {
                        _venueResults = [];
                        _hasSearchedWithNoResults = false;
                        _blockedVenueMatch = null;
                        _showingGoogleMapsResults = false;
                        _step1Notice = null;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.x,
                        size: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space8),

          if (_step1Notice != null) ...[
            _InlineNotice(
              icon: _step1NoticeIsError
                  ? LucideIcons.alertCircle
                  : LucideIcons.sparkles,
              title: _step1NoticeIsError ? 'Search Update' : 'Google Maps',
              message: _step1Notice!,
              color: _step1NoticeIsError ? cs.error : cs.primary,
            ),
            const SizedBox(height: AppTheme.space4),
          ],

          if (_blockedVenueMatch != null && _venueResults.isNotEmpty) ...[
            _InlineNotice(
              icon: LucideIcons.shieldAlert,
              title: _blockedVenueTitle(_blockedVenueMatch!),
              message: _blockedVenueMessage(_blockedVenueMatch!),
              color: AppColors.warning,
            ),
            const SizedBox(height: AppTheme.space4),
          ],

          if (_isSearching || _isSearchingGoogleMaps)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_venueResults.isNotEmpty) ...[
            Text(
              _showingGoogleMapsResults
                  ? 'GOOGLE MAPS RESULTS'
                  : 'SEARCH RESULTS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            ..._venueResults.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space3),
                child: _VenueSearchCard(venue: v, onTap: () => _selectVenue(v)),
              ),
            ),
          ] else if (_blockedVenueMatch != null) ...[
            _VenueUnavailableCard(
              title: _blockedVenueCardHeading(_blockedVenueMatch!),
              message: _blockedVenueMessage(_blockedVenueMatch!),
            ),
            const SizedBox(height: AppTheme.space8),
            Center(
              child: TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _venueResults = [];
                    _blockedVenueMatch = null;
                    _hasSearchedWithNoResults = false;
                  });
                },
                child: Text(
                  'RETURN TO PRIMARY SEARCH',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ] else if (_hasSearchedWithNoResults) ...[
            // ─ VENUE NOT FOUND ─
            const _VenueNotFoundCard(),
            const SizedBox(height: AppTheme.space6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSearchingGoogleMaps ? null : _searchGoogleMaps,
                icon: Icon(LucideIcons.search, size: 16, color: cs.primary),
                label: Text(
                  'SEARCH ON GOOGLE MAPS',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            // ─ OR divider ─
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: cs.outlineVariant.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space5,
                  ),
                  child: Text(
                    'O R',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: cs.outlineVariant.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            // ─ DIRECT MENU UPLOAD card ─
            PressableScale(
              onTap: () {
                final draft = ClaimedVenueDraft(
                  name: _lastSearchQuery,
                  address: '',
                  category: 'Restaurants',
                  description: '',
                );
                OnboardingDraftService.saveClaimedVenue(draft);
                setState(() {
                  _claimedVenue = draft;
                  _phase = _Phase.step2;
                  _selectedMenuAction = _Step2MenuAction.manual;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.space6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(color: AppColors.white5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: Icon(
                        LucideIcons.fileText,
                        size: 24,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space5),
                    Expanded(
                      child: Text(
                        'DIRECT\nMENU\nUPLOAD',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            // ─ RETURN TO PRIMARY SEARCH ─
            Center(
              child: TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _venueResults = [];
                    _hasSearchedWithNoResults = false;
                    _showingGoogleMapsResults = false;
                    _step1Notice = null;
                  });
                },
                child: Text(
                  'RETURN TO PRIMARY SEARCH',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ] else ...[
            // ─ FEATURED ESTABLISHMENTS ─
            Text(
              'FEATURED ESTABLISHMENTS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            if (_isFeaturedLoading) ...[
              _FeaturedVenueCardSkeleton(),
              const SizedBox(height: AppTheme.space3),
              _FeaturedVenueCardSkeleton(),
            ] else if (_featuredVenues.isEmpty) ...[
              const EmptyState(
                icon: LucideIcons.store,
                title: 'No venues yet',
                subtitle: 'Venues will appear here once added.',
              ),
            ] else ...[
              ..._featuredVenues.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space4),
                  child: _FeaturedVenueCard(
                    venue: v,
                    onTap: () => _selectVenue(v),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ═══ BUILDING LOADER ═══
  Widget _buildLoadingScreen(ColorScheme cs, TextTheme tt) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                      ),
                      child: Icon(
                        LucideIcons.sparkles,
                        size: 48,
                        color: cs.primary,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 1500.ms,
                      color: cs.primary.withValues(alpha: 0.15),
                    ),
                const SizedBox(height: AppTheme.space10),
                Text(
                  'BUILDING\nVENUE...',
                  textAlign: TextAlign.center,
                  style: tt.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'AI is inferring your identity, enriching with Maps data, and building your entire menu.',
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                AnimatedBuilder(
                  animation: _buildProgressCtrl,
                  builder: (_, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: LinearProgressIndicator(
                      value: _buildProgressCtrl.value,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space6),
                ...List.generate(
                  _buildStatuses.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _buildStatuses[i],
                      textAlign: TextAlign.center,
                      style: tt.labelMedium?.copyWith(
                        color: switch (i) {
                          0 => cs.primary,
                          1 when _buildStatusIndex >= 1 => cs.secondary,
                          _ => cs.onSurfaceVariant.withValues(
                            alpha: i <= _buildStatusIndex ? 0.65 : 0.35,
                          ),
                        },
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══ STEP 2: COMPLETE YOUR PROFILE ═══
  Widget _buildStep2(ColorScheme cs, TextTheme tt) {
    // Show OCR processing state
    if (_isProcessingOcr) {
      return Center(
        key: const ValueKey('step2-processing'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            const SizedBox(height: AppTheme.space6),
            Text(
              _ocrStatusMessage,
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              'This may take a moment…',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms);
    }

    return SingleChildScrollView(
      key: const ValueKey('step2'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error notice
          if (_error != null) ...[
            _InlineNotice(
              icon: LucideIcons.alertCircle,
              title: 'Error',
              message: _error!,
              color: cs.error,
            ),
            const SizedBox(height: AppTheme.space4),
          ],

          // Venue identified card
          if (_claimedVenue != null)
            _OnboardingPanel(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      LucideIcons.mapPin,
                      color: cs.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VENUE IDENTIFIED',
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space2),
                        Text(
                          _claimedVenue!.name,
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_claimedVenue!.address.isNotEmpty)
                          Text(
                            _claimedVenue!.address,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),

          const SizedBox(height: AppTheme.space8),

          // Upload option cards
          _DashedOptionCard(
            icon: LucideIcons.camera,
            title: 'Take Photo',
            subtitle: 'USE YOUR CAMERA',
            selected: _selectedMenuAction == _Step2MenuAction.photo,
            onTap: () =>
                setState(() => _selectedMenuAction = _Step2MenuAction.photo),
          ),
          const SizedBox(height: AppTheme.space4),
          _DashedOptionCard(
            icon: LucideIcons.upload,
            iconColor: AppColors.secondary,
            title: 'Upload PDF / Image',
            subtitle: 'FROM YOUR DEVICE',
            selected: _selectedMenuAction == _Step2MenuAction.upload,
            onTap: () =>
                setState(() => _selectedMenuAction = _Step2MenuAction.upload),
          ),
          const SizedBox(height: AppTheme.space4),
          _DashedOptionCard(
            icon: LucideIcons.fileText,
            iconColor: AppColors.tertiary,
            title: 'Add Manually',
            subtitle: 'TYPE YOUR MENU ITEMS',
            selected: _selectedMenuAction == _Step2MenuAction.manual,
            onTap: () =>
                setState(() => _selectedMenuAction = _Step2MenuAction.manual),
          ),
        ],
      ),
    );
  }

  // ═══ STEP 3: REVIEW MENU ═══
  Widget _buildStep3(ColorScheme cs, TextTheme tt) {
    final reviewCount = _draftItems.where((i) => i.requiresReview).length;
    return SingleChildScrollView(
      key: const ValueKey('step3'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reviewCount > 0) ...[
            _SectionEyebrow(
              icon: LucideIcons.sparkles,
              label: 'Review Exceptions',
            ),
            const SizedBox(height: AppTheme.space3),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu Items',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (reviewCount > 0)
                TextButton(
                  onPressed: _approveAll,
                  child: Text(
                    'APPROVE ALL',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          if (_draftItems.isEmpty)
            const EmptyState(
              icon: LucideIcons.utensils,
              title: 'No menu items yet',
              subtitle: 'Add items manually or go back to upload.',
            ),
          ..._draftItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space4),
              child: _MenuItemCard(
                item: item,
                onEdit: () => _showEditItemDialog(i),
                onDelete: () => _deleteItem(i),
              ),
            );
          }),
          const SizedBox(height: AppTheme.space4),
          _DashedAddButton(onTap: _showAddItemDialog),
          const SizedBox(height: AppTheme.space6),
        ],
      ),
    );
  }

  // ═══ STEP 4: ACTIVATE VENUE ═══
  Widget _buildStep4(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      key: const ValueKey('step4'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            _InlineNotice(
              icon: LucideIcons.alertCircle,
              title: 'Error',
              message: _error!,
              color: cs.error,
            ),
            const SizedBox(height: AppTheme.space4),
          ],
          if (_info != null) ...[
            _InlineNotice(
              icon: LucideIcons.messageSquare,
              title: 'Info',
              message: _info!,
              color: cs.secondary,
            ),
            const SizedBox(height: AppTheme.space4),
          ],
          if (_otpStep == 'phone' && _hasVerifiedMenuAccess)
            _buildVerifiedSubmitPanel(cs, tt),
          if (_otpStep == 'phone' && !_hasVerifiedMenuAccess)
            _buildPhoneInput(cs, tt),
          if (_otpStep == 'otp') _buildOtpInput(cs, tt),
        ],
      ),
    );
  }

  Widget _buildPhoneInput(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHATSAPP NUMBER',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        CountryPhoneInput.fromConfig(
          config: CountryRuntime.config,
          controller: _phoneCtrl,
          onSubmitted: _canSendOtp ? _sendOtp : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppTheme.space8),
        OtpActionButton.gold(
          label: 'Get OTP',
          icon: const WhatsAppIcon(),
          isLoading: _isLoading,
          onPressed: _canSendOtp ? _sendOtp : null,
        ),
      ],
    );
  }

  Widget _buildVerifiedSubmitPanel(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OnboardingPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VERIFIED WHATSAPP',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: AppTheme.space2),
              Text(_verifiedContactPhone ?? '', style: tt.titleMedium),
              const SizedBox(height: AppTheme.space2),
              Text(
                'Your identity is already verified. Submit the venue claim when you are ready.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        OtpActionButton.green(
          label: 'Submit Claim',
          icon: Icon(
            LucideIcons.checkCircle2,
            size: 22,
            color: AppColors.onSecondary,
          ),
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submitClaimWithVerifiedPhone,
        ),
      ],
    );
  }

  Widget _buildOtpInput(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        OtpPillFields(
          controllers: _otpCtrls,
          focusNodes: _otpFocus,
          onComplete: _isLoading ? null : _verifyAndSubmit,
        ),
        const SizedBox(height: AppTheme.space8),
        OtpActionButton.green(
          label: 'Submit',
          icon: Icon(
            LucideIcons.checkCircle2,
            size: 22,
            color: AppColors.onSecondary,
          ),
          isLoading: _isLoading,
          onPressed: _verifyAndSubmit,
        ),
        const SizedBox(height: AppTheme.space4),
        Center(
          child: Text(
            _resendSeconds > 0
                ? 'Resend Code in ${_resendSeconds}s'
                : 'Resend Code',
            style: tt.bodyMedium?.copyWith(
              color: _resendSeconds > 0
                  ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                  : cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_resendSeconds <= 0)
          Center(
            child: TextButton(
              onPressed: _sendOtp,
              child: Text(
                'TAP TO RESEND',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══ SUBMITTED SCREEN ═══
  Widget _buildSubmittedScreen(ColorScheme cs, TextTheme tt) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space8),
          child: Column(
            children: [
              Row(
                children: [
                  _BackButton(
                    onTap: () => context.goNamed(AppRouteNames.splash),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                ),
                child: Icon(
                  LucideIcons.shieldCheck,
                  size: 64,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text('Verification Pending', style: tt.displaySmall),
              const SizedBox(height: AppTheme.space4),
              Text(
                'Your venue claim has been submitted. We will review and activate it shortly.',
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.goNamed(AppRouteNames.splash),
                  child: const Text('RETURN HOME'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// REUSABLE SUB-WIDGETS
// ════════════════════════════════════════════

class _OnboardingPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? backgroundColor;

  const _OnboardingPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space6),
    this.radius = AppTheme.radiusXxl,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.white5),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: child,
    );
  }
}

class _OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _OnboardingPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final enabled = onPressed != null;
    return PressableScale(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 74,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(20),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Icon(icon, color: AppColors.onPrimary, size: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionEyebrow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: AppTheme.space2),
        Text(
          label.toUpperCase(),
          style: tt.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _EditorFieldLabel extends StatelessWidget {
  final String label;

  const _EditorFieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }
}

class _OnboardingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  const _OnboardingTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant.withValues(alpha: 0.42),
        ),
        filled: true,
        fillColor: cs.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space5,
          vertical: AppTheme.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.white5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.white5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final String label;
  final bool emphasized;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bg = emphasized ? AppColors.primary : AppColors.surfaceContainer;
    final fg = emphasized ? AppColors.onPrimary : AppColors.onSurface;
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: emphasized
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: Text(
            label,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _VenueNotFoundCard extends StatelessWidget {
  const _VenueNotFoundCard();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppColors.white5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(LucideIcons.x, size: 20, color: cs.error),
              ),
              const SizedBox(width: AppTheme.space4),
              Text(
                'VENUE\nNOT\nFOUND',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            "We couldn't find an exact match in our primary database.",
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueUnavailableCard extends StatelessWidget {
  final String title;
  final String message;

  const _VenueUnavailableCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppColors.white5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  LucideIcons.shieldAlert,
                  size: 20,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Text(
                title,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            message,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.white5),
        ),
        child: const Icon(LucideIcons.chevronLeft, size: 24),
      ),
    );
  }
}

class _VenueSearchCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  final VoidCallback onTap;
  const _VenueSearchCard({required this.venue, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final source = venue['source'] as String?;
    return PressableScale(
      onTap: onTap,
      child: _OnboardingPanel(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (source == 'google_maps' ? cs.secondary : cs.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                source == 'google_maps'
                    ? LucideIcons.mapPin
                    : LucideIcons.store,
                size: 24,
                color: source == 'google_maps' ? cs.secondary : cs.primary,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (source == 'google_maps')
                    Text(
                      'GOOGLE MAPS',
                      style: tt.labelSmall?.copyWith(
                        color: cs.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  Text(
                    venue['name'] as String? ?? '',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (venue['address'] != null)
                    Text(
                      venue['address'] as String,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedVenueCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  final VoidCallback onTap;
  const _FeaturedVenueCard({required this.venue, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = venue['name'] as String? ?? '';
    final address = venue['address'] as String? ?? '';
    final category = venue['category'] as String? ?? 'Restaurant';
    final rating = (venue['rating'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = venue['image_url'] as String?;

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 182,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(color: AppColors.white5),
        ),
        child: Stack(
          children: [
            // Background image or gradient fallback
            if (imageUrl != null && imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _gradientFallback(cs),
                ),
              )
            else
              Positioned.fill(child: _gradientFallback(cs)),
            // Dark gradient overlay for readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
            // Category badge (top right)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
            // Bottom info
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rating > 0) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 12, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    name,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientFallback(ColorScheme cs) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cs.surfaceContainerHigh, cs.surfaceContainerLow],
      ),
    ),
  );
}

class _FeaturedVenueCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 182,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppColors.white5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SkeletonLoader(width: 60, height: 16),
            const SizedBox(height: 8),
            SkeletonLoader(width: 180, height: 18),
            const SizedBox(height: 6),
            SkeletonLoader(width: 120, height: 12),
          ],
        ),
      ),
    );
  }
}

class _DashedOptionCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _DashedOptionCard({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.selected = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = iconColor ?? cs.primary;
    return PressableScale(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: _RoundedDashedBorderPainter(
          color: selected
              ? color.withValues(alpha: 0.75)
              : cs.outlineVariant.withValues(alpha: 0.55),
          radius: AppTheme.radiusXxl,
          strokeWidth: 1.2,
          dashLength: 7,
          gapLength: 5,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space6),
          decoration: BoxDecoration(
            color: selected
                ? cs.surfaceContainer.withValues(alpha: 0.98)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: AppTheme.space5),
              Text(
                title,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final OcrDraftMenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space5,
        vertical: AppTheme.space5,
      ),
      decoration: BoxDecoration(
        color: item.requiresReview
            ? cs.surfaceContainerLow
            : const Color(0xFF151E17),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: item.requiresReview
              ? AppColors.white5
              : AppColors.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${CountryRuntime.config.country.currencySymbol}${item.price.toStringAsFixed(2)}',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          _RoundActionButton(
            icon: LucideIcons.pencil,
            color: cs.onSurfaceVariant,
            background: cs.surfaceContainer,
            onTap: onEdit,
          ),
          const SizedBox(width: AppTheme.space3),
          _RoundActionButton(
            icon: LucideIcons.trash2,
            color: cs.error,
            background: const Color(0x332C1A1A),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DashedAddButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return PressableScale(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: _RoundedDashedBorderPainter(
          color: cs.outlineVariant.withValues(alpha: 0.55),
          radius: AppTheme.radiusXxl,
          strokeWidth: 1.2,
          dashLength: 7,
          gapLength: 5,
        ),

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            color: cs.surfaceContainerLowest,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.plus, size: 18, color: cs.onSurface),
              ),
              const SizedBox(width: 12),
              Text(
                'ADD MANUAL ITEM',
                style: tt.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _RoundedDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const _RoundedDashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.2,
    this.dashLength = 7,
    this.gapLength = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        final segmentEnd = next > metric.length ? metric.length : next;
        canvas.drawPath(metric.extractPath(distance, segmentEnd), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedDashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength;
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleSmall?.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(message, style: tt.bodySmall?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

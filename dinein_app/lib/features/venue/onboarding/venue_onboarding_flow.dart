import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/enums.dart';

import '../../../core/router/app_routes.dart';
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

class VenueOnboardingFlow extends StatefulWidget {
  const VenueOnboardingFlow({super.key});
  @override
  State<VenueOnboardingFlow> createState() => _VenueOnboardingFlowState();
}

class _VenueOnboardingFlowState extends State<VenueOnboardingFlow>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.step1;

  // Step 1
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _venueResults = [];
  bool _isSearching = false;
  bool _hasSearchedWithNoResults = false;
  String _lastSearchQuery = '';
  List<Map<String, dynamic>> _featuredVenues = [];
  bool _isFeaturedLoading = true;
  Timer? _debounce;

  // Building loader
  late AnimationController _buildProgressCtrl;
  int _buildStatusIndex = 0;
  static const _buildStatuses = [
    'INFERRING IDENTITY…',
    'ENRICHING MAPS DATA…',
    'PREPARING VENUE…',
  ];

  // Step 2 / 3
  ClaimedVenueDraft? _claimedVenue;
  List<OcrDraftMenuItem> _draftItems = [];
  bool _isProcessingOcr = false;
  String _ocrStatusMessage = 'UPLOADING FILE…';

  // Step 4
  final _phoneCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  final String _countryCode = '+356';
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
    if (!mounted) return;
    setState(() {
      _claimedVenue = venue;
      _draftItems = items;
    });
  }

  Future<void> _loadFeaturedVenues() async {
    try {
      final venues = await VenueRepository.instance.getVenues(limit: 6);
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
        return _otpStep == 'phone' ? 'Activate Venue' : 'Verify Identity';
    }
  }

  bool get _showStepHeader => _phase != _Phase.building;

  // ─── NAVIGATION ───
  void _goBack() {
    switch (_phase) {
      case _Phase.step1:
        context.pop();
      case _Phase.building:
        setState(() => _phase = _Phase.step1);
      case _Phase.step2:
        setState(() => _phase = _Phase.step1);
      case _Phase.step3:
        setState(() => _phase = _Phase.step2);
      case _Phase.step4:
        if (_otpStep == 'otp') {
          setState(() {
            _otpStep = 'phone';
            _error = null;
          });
        } else {
          setState(() => _phase = _Phase.step3);
        }
    }
  }

  // ─── SEARCH (Step 1) ───
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _venueResults = [];
        _isSearching = false;
        _hasSearchedWithNoResults = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchVenues(query.trim()),
    );
  }

  Future<void> _searchVenues(String query) async {
    try {
      final allVenues = await VenueRepository.instance.getVenues();
      if (!mounted) return;
      final lowerQuery = query.toLowerCase();
      final filtered = allVenues
          .where(
            (v) =>
                v.name.toLowerCase().contains(lowerQuery) ||
                v.address.toLowerCase().contains(lowerQuery) ||
                v.category.toLowerCase().contains(lowerQuery),
          )
          .take(10)
          .toList();
      setState(() {
        _venueResults = filtered
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
        _hasSearchedWithNoResults = filtered.isEmpty;
        _lastSearchQuery = query;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectVenue(Map<String, dynamic> venue) async {
    final draft = ClaimedVenueDraft(
      venueId: venue['id'] as String?,
      name: venue['name'] as String? ?? '',
      address: venue['address'] as String? ?? '',
      category: venue['category'] as String? ?? 'Restaurants',
      description: '',
    );
    await OnboardingDraftService.saveClaimedVenue(draft);
    if (!mounted) return;
    setState(() {
      _claimedVenue = draft;
      _phase = _Phase.building;
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
  Future<void> _takePhoto() async {
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
        _error = 'File selection failed. Please try again.';
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
      final fileUrl = await MenuRepository.instance.uploadMenuFile(filePath);
      if (!mounted) return;
      setState(() => _ocrStatusMessage = 'EXTRACTING MENU…');

      // OCR extraction via Gemini
      final items = await MenuRepository.instance.extractMenuFromFile(fileUrl);
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
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD ITEM',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTheme.space6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Item Name'),
                ),
                const SizedBox(height: AppTheme.space4),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Price (${Country.mt.currencySymbol})',
                    prefixText: '${Country.mt.currencySymbol} ',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(hintText: 'Category'),
                ),
                const SizedBox(height: AppTheme.space8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: PremiumButton(
                        label: 'Save',
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final price =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (name.isEmpty) return;
                          setState(
                            () => _draftItems.add(
                              OcrDraftMenuItem(
                                name: name,
                                description: '',
                                price: price,
                                category: catCtrl.text.trim(),
                              ),
                            ),
                          );
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

  void _showEditItemDialog(int index) {
    final item = _draftItems[index];
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(
      text: item.price.toStringAsFixed(2),
    );
    final catCtrl = TextEditingController(text: item.category);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EDIT ITEM',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTheme.space6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'Item Name'),
                ),
                const SizedBox(height: AppTheme.space4),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Price (${Country.mt.currencySymbol})',
                    prefixText: '${Country.mt.currencySymbol} ',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(hintText: 'Category'),
                ),
                const SizedBox(height: AppTheme.space8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: PremiumButton(
                        label: 'Save',
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final price =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (name.isEmpty) return;
                          setState(
                            () => _draftItems[index] = item.copyWith(
                              name: name,
                              price: price,
                              category: catCtrl.text.trim(),
                              requiresReview: false,
                            ),
                          );
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
  String get _normalizedPhone {
    final local = _phoneCtrl.text.trim();
    if (local.isEmpty) return '';
    final digits = local.replaceAll(RegExp(r'[^0-9]'), '');
    if (local.startsWith('+')) return '+$digits';
    final cc = _countryCode.replaceAll(RegExp(r'[^0-9]'), '');
    return '+$cc$digits';
  }

  Future<void> _sendOtp() async {
    final phone = _normalizedPhone;
    if (phone.length < 8) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      final challenge = await WhatsAppOtpService.instance.sendOtp(phone);
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
    );
    if (!result.verified) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Invalid code. Request a fresh one.';
      });
      return;
    }

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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not register venue. Please try again.';
      });
      return;
    }

    // Submit claim for admin review.
    try {
      await ClaimRepository.instance.submitClaim(
        venueId: resolved.venueId!,
        venueName: resolved.name,
        venueArea: resolved.address,
        contactPhone: _normalizedPhone,
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
      contactPhone: _normalizedPhone,
      claimSubmitted: true,
    );
    await OnboardingDraftService.saveClaimedVenue(persisted);

    final matchedVenueSession =
        result.venueSession != null &&
            result.venueSession!.venueId == resolved.venueId
        ? result.venueSession
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

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _otpStep = 'submitted';
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
                    _stepTitle,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
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
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                label: 'Submit Menu',
                icon: LucideIcons.arrowRight,
                onPressed: () => setState(() => _phase = _Phase.step4),
              ),
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

          if (_isSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_venueResults.isNotEmpty) ...[
            Text(
              'SEARCH RESULTS',
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
          ] else if (_hasSearchedWithNoResults) ...[
            // ─ VENUE NOT FOUND ─
            const _VenueNotFoundCard(),
            const SizedBox(height: AppTheme.space8),
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
                  'BUILDING VENUE...',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i < _buildStatusIndex
                              ? LucideIcons.checkCircle2
                              : i == _buildStatusIndex
                              ? LucideIcons.loader2
                              : LucideIcons.circle,
                          size: 14,
                          color: i <= _buildStatusIndex
                              ? cs.primary
                              : cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _buildStatuses[i],
                          style: tt.labelSmall?.copyWith(
                            color: i <= _buildStatusIndex
                                ? cs.onSurface
                                : cs.onSurfaceVariant.withValues(alpha: 0.3),
                            fontWeight: i == _buildStatusIndex
                                ? FontWeight.w800
                                : FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
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
            Container(
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Icon(
                      LucideIcons.mapPin,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
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
                        const SizedBox(height: 2),
                        Text(_claimedVenue!.name, style: tt.titleMedium),
                        Text(
                          _claimedVenue!.address,
                          style: tt.bodySmall?.copyWith(
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
            onTap: _takePhoto,
          ),
          const SizedBox(height: AppTheme.space4),
          _DashedOptionCard(
            icon: LucideIcons.upload,
            iconColor: AppColors.secondary,
            title: 'Upload PDF / Image',
            subtitle: 'FROM YOUR DEVICE',
            onTap: _uploadFile,
          ),
          const SizedBox(height: AppTheme.space4),
          _DashedOptionCard(
            icon: LucideIcons.fileText,
            iconColor: cs.onSurfaceVariant,
            title: 'Add Manually',
            subtitle: 'TYPE YOUR MENU ITEMS',
            onTap: _addManually,
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
          if (reviewCount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Review Needed',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _approveAll,
                  child: Text(
                    'APPROVE ALL',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          if (reviewCount > 0) const SizedBox(height: AppTheme.space4),
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
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
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
          if (_otpStep == 'phone') _buildPhoneInput(cs, tt),
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
        MaltaPhoneInput(controller: _phoneCtrl, onSubmitted: _sendOtp),
        const SizedBox(height: AppTheme.space8),
        OtpActionButton.gold(
          label: 'Get OTP',
          icon: const WhatsAppIcon(),
          isLoading: _isLoading,
          onPressed: _phoneCtrl.text.trim().length >= 4 ? _sendOtp : null,
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
    return PressableScale(
      onTap: onTap,
      child: ClayCard(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(LucideIcons.store, size: 22, color: cs.primary),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue['name'] as String? ?? '',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (venue['address'] != null)
                    Text(
                      venue['address'] as String,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (venue['category'] != null)
              StatusBadge(label: venue['category'] as String),
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
        height: 140,
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
      height: 140,
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
  final VoidCallback onTap;
  const _DashedOptionCard({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = iconColor ?? cs.primary;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.20),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppColors.white5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(label: item.category),
                    if (item.requiresReview) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                        child: Text(
                          'REVIEW NEEDED',
                          style: tt.labelSmall?.copyWith(
                            color: AppColors.secondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${Country.mt.currencySymbol}${item.price.toStringAsFixed(2)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.pencil,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 16, color: cs.error),
            onPressed: onDelete,
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.space5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.30),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'ADD MANUAL ITEM',
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../web_breakpoints.dart';
import '../web_tokens.dart';
import 'sections/about_section.dart';
import 'sections/contacts_section.dart';
import 'sections/download_section.dart';
import 'sections/hero_section.dart';
import 'sections/web_footer.dart';
import 'web_nav_bar.dart';

/// The public marketing page at `/`.
///
/// The only screen in the app outside the auth guard. Its hero is composed
/// after a night-sky landing reference and is the front door to browsing:
/// every tile in it opens the app's Shop filtered to that category. Its
/// tokens live in [WebInk] and [WebType], because a page read once by a
/// stranger on a 27-inch monitor has different problems from a phone app
/// used daily — but its canvas is the app's own night, so arriving in the app
/// from here does not feel like changing products.
///
/// Section rhythm is deliberately uneven: a centred hero with a tiled stage,
/// a two-column About with a working diagram, Contacts as full-width rows,
/// then Download as a brand-blue panel. Nothing repeats the same composition
/// twice, which is the difference between a page and a template. The order
/// follows the nav, so the bar reads as a table of contents.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();

  final _aboutKey = GlobalKey();
  final _contactsKey = GlobalKey();
  final _downloadKey = GlobalKey();

  bool _scrolled = false;

  /// The section in view, for the nav's indicator. Null over the hero.
  int? _activeSection;

  late final List<WebNavDestination> _destinations = [
    WebNavDestination.section('About Us', _aboutKey),
    WebNavDestination.section('Contacts', _contactsKey),
    WebNavDestination.section('Download the app', _downloadKey),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 8;
    final active = _sectionInView();
    if (scrolled != _scrolled || active != _activeSection) {
      setState(() {
        _scrolled = scrolled;
        _activeSection = active;
      });
    }
  }

  /// The last section whose top has passed the upper third of the viewport.
  /// A third rather than the top edge, so a section counts as "current" once
  /// it fills most of the screen, not only once it touches the bar.
  int? _sectionInView() {
    final line = MediaQuery.sizeOf(context).height * 0.34;
    int? active;
    for (var i = 0; i < _destinations.length; i++) {
      final ctx = _destinations[i].sectionKey?.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if (box.localToGlobal(Offset.zero).dy <= line) active = i;
    }
    return active;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) => scrollToSection(key);

  void _openMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WebInk.raised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final d in _destinations)
                _SheetItem(
                  label: d.label,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (d.sectionKey != null) _scrollTo(d.sectionKey!);
                  },
                ),
              const SizedBox(height: 10),
              const WebRule(),
              const SizedBox(height: 10),
              _SheetItem(
                label: 'Sign in',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(signInLocation);
                },
              ),
              _SheetItem(
                label: 'Browse vendors',
                emphasis: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(shopLocation());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);
    final gap = brk.sectionGap;

    return Scaffold(
      backgroundColor: WebInk.canvas,
      body: Stack(
        children: [
          Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  SizedBox(
                    height: WebNavBar.height + (brk.isCompact ? 32 : 48),
                  ),

                  const HeroSection(),

                  SizedBox(height: gap),
                  KeyedSubtree(key: _aboutKey, child: const AboutSection()),

                  SizedBox(height: gap),
                  KeyedSubtree(
                    key: _contactsKey,
                    child: const ContactsSection(),
                  ),

                  SizedBox(height: gap),
                  KeyedSubtree(
                    key: _downloadKey,
                    child: const DownloadSection(),
                  ),

                  const WebFooter(),
                ],
              ),
            ),
          ),

          // The bar floats over the scroll view so "Browse vendors" is reachable
          // from anywhere on a long page. It is transparent until the content
          // passes under it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: WebNavBar(
              destinations: _destinations,
              onMenuTap: _openMobileMenu,
              scrolled: _scrolled,
              activeIndex: _activeSection,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.label,
    required this.onTap,
    this.emphasis = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          label,
          style: WebType.entry(
            WebBreak.compact,
            color: emphasis ? WebInk.accent : WebInk.text,
          ).copyWith(fontSize: 18),
        ),
      ),
    );
  }
}

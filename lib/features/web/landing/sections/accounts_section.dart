import 'package:flutter/material.dart';

import '../../web_breakpoints.dart';
import '../../web_tokens.dart';
import '../../widgets/web_motion.dart';

/// The three account types.
///
/// A sticky statement on the left, the accounts as a ruled list on the right.
/// The asymmetry is the hierarchy: the left column says what the section is
/// about once and then holds still while the three entries scroll past it.
/// That is a different shape from the run section's full-width rows and from
/// the weather table, which is what keeps the page from reading as one
/// repeated template.
class AccountsSection extends StatelessWidget {
  const AccountsSection({super.key});

  static const _accounts = <_Account>[
    _Account(
      'Students, faculty and staff',
      'Open to anyone with a campus email.',
      'Browse approved vendors, build a cart, pick the building you want it '
          'delivered to, and follow the drone in. Order history and receipts '
          'stay in the account.',
      ['Old / Main', 'Annex 1', 'Annex 2', 'Basic Education', 'Maritime'],
      'Drop-off points',
    ),
    _Account(
      'Vendors',
      'Approved by an administrator before the dashboard opens.',
      'Manage products, price, weight and stock. Work incoming orders through '
          'confirm, prepare and ready-to-fly. Stock updates itself as orders '
          'complete, and the weight you set on each product feeds the payload '
          'check.',
      [],
      null,
    ),
    _Account(
      'Administrators',
      'Created by hand. There is no public route to this account.',
      'Approve or reject vendor applications, assign drones, monitor battery '
          'and fleet status, set the campus weather condition, and keep the '
          'restricted-airspace records.',
      [],
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    final statement = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Accounts', style: WebType.meta(color: WebInk.accent)),
        const SizedBox(height: 18),
        Text('One sign-in,\nthree systems.', style: WebType.title(brk)),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'The same credentials open a different product depending on who '
            'you are. Vendor and administrator accounts are approved by hand.',
            style: WebType.body(),
          ),
        ),
      ],
    );

    final list = Column(
      children: [
        const WebRule(),
        for (var i = 0; i < _accounts.length; i++)
          RevealOnScroll(
            delay: WebMotion.stagger * i,
            child: Column(
              children: [_AccountEntry(_accounts[i]), const WebRule()],
            ),
          ),
      ],
    );

    return WebContentFrame(
      child: brk.isExpanded
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 36, child: RevealOnScroll(child: statement)),
                const SizedBox(width: 72),
                Expanded(flex: 64, child: list),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RevealOnScroll(child: statement),
                SizedBox(height: brk.isCompact ? 44 : 60),
                list,
              ],
            ),
    );
  }
}

class _Account {
  const _Account(this.title, this.access, this.body, this.tags, this.tagsLabel);

  final String title;
  final String access;
  final String body;
  final List<String> tags;
  final String? tagsLabel;
}

class _AccountEntry extends StatelessWidget {
  const _AccountEntry(this.account);
  final _Account account;

  @override
  Widget build(BuildContext context) {
    final brk = webBreakOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: brk.isCompact ? 28 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account.title, style: WebType.entry(brk)),
          const SizedBox(height: 7),
          Text(
            account.access,
            style: WebType.meta(color: WebInk.textSoft).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(account.body, style: WebType.body()),
          if (account.tags.isNotEmpty) ...[
            const SizedBox(height: 22),
            if (account.tagsLabel != null) ...[
              Text(account.tagsLabel!, style: WebType.meta()),
              const SizedBox(height: 12),
            ],
            // Building names set as type separated by rules, not as pills. A
            // row of capsules would read as filter chips you can press.
            _TagRun(account.tags),
          ],
        ],
      ),
    );
  }
}

class _TagRun extends StatelessWidget {
  const _TagRun(this.tags);
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    // Each child is bounded before entering the Wrap. A Wrap gives children
    // unbounded width, so an unconstrained Row inside one never wraps and
    // overflows the viewport instead.
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 0,
        runSpacing: 10,
        children: [
          for (var i = 0; i < tags.length; i++)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 13,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: WebInk.rule,
                    ),
                  Flexible(
                    child: Text(
                      tags[i],
                      style: WebType.body(
                        color: WebInk.text,
                      ).copyWith(fontSize: 14.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

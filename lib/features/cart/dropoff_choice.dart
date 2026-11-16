import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import 'dropoff_map_picker.dart';

/// Whether the next order goes to a pin the customer placed on the map.
///
/// The one place the pin lives, shared by the home "Deliver to" control and
/// checkout so the two can never disagree. Kept for the session only and never
/// written to the profile: a pin has no campus location id.
///
/// [pin] is the last confirmed pin and [usePin] says whether it is in use.
/// Checkout switching to a campus point keeps the pin for a quick switch back;
/// choosing a building from the home control forgets it.
class DropoffChoice {
  final bool usePin;
  final PinnedDropoff? pin;

  const DropoffChoice({this.usePin = false, this.pin});
}

class DropoffChoiceNotifier extends Notifier<DropoffChoice> {
  @override
  DropoffChoice build() {
    // Belongs to the signed-in customer: signing out, or in as someone else,
    // starts empty.
    ref.watch(authProvider.select((s) => s.user?.id));
    return const DropoffChoice();
  }

  /// A confirmed pin, from either place: it becomes the drop-off.
  void choosePin(PinnedDropoff pin) =>
      state = DropoffChoice(usePin: true, pin: pin);

  /// Back to the campus point, keeping the pin (checkout's radio).
  void chooseCampusPoint() => state = DropoffChoice(pin: state.pin);

  /// A building chosen from the home control: the pin is gone.
  void forgetPin() => state = const DropoffChoice();
}

final dropoffChoiceProvider =
    NotifierProvider<DropoffChoiceNotifier, DropoffChoice>(
      DropoffChoiceNotifier.new,
    );
